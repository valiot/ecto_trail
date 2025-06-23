defmodule EctoTrailLogOnlyTest do
  use EctoTrail.DataCase
  alias EctoTrail.Changelog
  doctest EctoTrail

  describe "log_bulk" do
    test "logs inserted structs with associated changes" do
      changes_list = [%{name: "My name"}, %{name: "Your name"}]

      dt_now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

      ready_changes =
        Enum.map(changes_list, fn change ->
          change
          |> Map.update(:inserted_at, dt_now, fn dt -> dt end)
          |> Map.update(:updated_at, dt_now, fn dt -> dt end)
        end)

      {_n, structs_list} = TestRepo.insert_all(Resource, ready_changes, returning: true)

      # logging inserted
      result = TestRepo.log_bulk(structs_list, changes_list, "cowboy", :insert)

      ids = Enum.map(structs_list, fn inserted_struct -> inserted_struct.id end)

      assert {:ok, returned_structs} = result
      assert length(returned_structs) == length(structs_list)

      Enum.each(Enum.zip([ids, changes_list]), fn {an_id, _a_change} ->
        assert %{
                 changeset: _a_change,
                 actor_id: "cowboy",
                 change_type: :insert
               } = TestRepo.get_by(Changelog, %{resource_id: an_id |> to_string()})
      end)

      # logging deleted
      {_n, deleted_objects_list} = TestRepo.delete_all(from(s in Resource, where: s.id in ^ids, select: s))

      associations = (fn s -> s.__struct__.__schema__(:associations) end).(struct(Resource))

      changeset_like_maps =
        Enum.map(
          deleted_objects_list,
          fn deleted_object ->
            Map.from_struct(deleted_object)
            |> Map.delete(:__meta__)
            |> Enum.reduce(%{}, fn {key, value}, acc ->
              if key in associations do
                Map.put(acc, key, nil)
              else
                Map.put(acc, key, value)
              end
            end)
          end
        )

      TestRepo.log_bulk(
        deleted_objects_list,
        changeset_like_maps,
        "cowboy",
        :delete
      )

      Enum.each(Enum.zip([ids, changeset_like_maps]), fn {an_id, _a_change} ->
        assert %{
                 changeset: _a_change,
                 actor_id: "cowboy",
                 change_type: :delete
               } =
                 TestRepo.get_by(Changelog, %{resource_id: an_id |> to_string(), change_type: :delete})
      end)
    end

    test "performs bulk insert in a single database operation" do
      # Create test data
      changes_list = [%{name: "Bulk test 1"}, %{name: "Bulk test 2"}, %{name: "Bulk test 3"}]

      dt_now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

      ready_changes =
        Enum.map(changes_list, fn change ->
          change
          |> Map.update(:inserted_at, dt_now, fn dt -> dt end)
          |> Map.update(:updated_at, dt_now, fn dt -> dt end)
        end)

      {_n, structs_list} = TestRepo.insert_all(Resource, ready_changes, returning: true)

      # Perform bulk logging
      result = TestRepo.log_bulk(structs_list, changes_list, "bulk_actor", :insert)

      # Verify successful operation
      assert {:ok, returned_structs} = result
      assert length(returned_structs) == length(structs_list)

      # Verify all entries were inserted correctly
      inserted_logs = TestRepo.all(from(c in Changelog, where: c.actor_id == "bulk_actor"))
      assert length(inserted_logs) == length(structs_list)

      # Verify content matches
      names = Enum.map(inserted_logs, fn log -> log.changeset["name"] end) |> Enum.sort()
      expected_names = ["Bulk test 1", "Bulk test 2", "Bulk test 3"]
      assert names == expected_names
    end

    test "uses single database write operation" do
      # Create test data
      changes_list = [%{name: "Write Test 1"}, %{name: "Write Test 2"}]

      dt_now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

      ready_changes =
        Enum.map(changes_list, fn change ->
          change
          |> Map.update(:inserted_at, dt_now, fn dt -> dt end)
          |> Map.update(:updated_at, dt_now, fn dt -> dt end)
        end)

      {_n, structs_list} = TestRepo.insert_all(Resource, ready_changes, returning: true)

      # Capture SQL logs
      log_output =
        ExUnit.CaptureLog.capture_log([level: :debug], fn ->
          result = TestRepo.log_bulk(structs_list, changes_list, "write_test_actor", :insert)
          assert {:ok, returned_structs} = result
          assert length(returned_structs) == length(structs_list)
        end)

      # Count INSERT operations on audit_log
      audit_log_inserts =
        log_output
        |> String.split("\n")
        |> Enum.filter(fn line ->
          String.contains?(line, "INSERT INTO \"audit_log\"") and
            String.contains?(line, "write_test_actor")
        end)

      # Assert exactly one INSERT operation
      assert length(audit_log_inserts) == 1,
             "Expected 1 INSERT operation, found #{length(audit_log_inserts)}"

      # Verify all records were inserted
      inserted_logs = TestRepo.all(from(c in Changelog, where: c.actor_id == "write_test_actor"))
      assert length(inserted_logs) == length(structs_list)
    end
  end
end
