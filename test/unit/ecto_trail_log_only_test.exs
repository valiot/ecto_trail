defmodule EctoTrailLogOnlyTest do
  use EctoTrail.DataCase
  alias EctoTrail.Changelog
  alias Ecto.Changeset
  alias Ecto.Multi
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

      assert :ok = result

      Enum.each(Enum.zip([ids, changes_list]), fn {an_id, a_change} ->
        assert %{
                 changeset: a_change,
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

      Enum.each(Enum.zip([ids, changeset_like_maps]), fn {an_id, a_change} ->
        assert %{
                 changeset: a_change,
                 actor_id: "cowboy",
                 change_type: :delete
               } =
                 TestRepo.get_by(Changelog, %{resource_id: an_id |> to_string(), change_type: :delete})
      end)
    end
  end
end
