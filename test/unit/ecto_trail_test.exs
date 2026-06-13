defmodule EctoTrailTest do
  use EctoTrail.DataCase
  alias EctoTrail.Changelog
  alias Ecto.Changeset
  alias Ecto.Multi
  doctest EctoTrail

  describe "insert_and_log/3" do
    test "logs changes when schema is inserted" do
      result = TestRepo.insert_and_log(%Resource{name: "name"}, "cowboy")
      assert {:ok, %Resource{name: "name"}} = result

      resource = TestRepo.one(Resource)
      resource_id = to_string(resource.id)

      assert %{
               changeset: %{},
               actor_id: "cowboy",
               resource_id: ^resource_id,
               resource: "resources",
               change_type: :insert
             } = TestRepo.one(Changelog)
    end

    test "logs changes when changeset is inserted" do
      result =
        %Resource{}
        |> Changeset.change(%{name: "My name"})
        |> TestRepo.insert_and_log("cowboy")

      assert {:ok, %Resource{name: "My name"}} = result

      resource = TestRepo.one(Resource)
      resource_id = to_string(resource.id)

      assert %{
               changeset: %{"name" => "My name"},
               actor_id: "cowboy",
               resource_id: ^resource_id,
               resource: "resources",
               change_type: :insert
             } = TestRepo.one(Changelog)
    end

    test "logs changes with redacted field when changeset is inserted" do
      result =
        %Resource{}
        |> Changeset.change(%{name: "My password Redacted", password: "secret"})
        |> TestRepo.insert_and_log("cowboy")

      assert {:ok, %Resource{name: "My password Redacted", password: "secret"}} = result
      resource = TestRepo.one(Resource)
      resource_id = to_string(resource.id)

      assert %{
               changeset: changeset,
               actor_id: "cowboy",
               resource_id: ^resource_id,
               resource: "resources",
               change_type: :insert
             } = TestRepo.one(Changelog)

      # Account for the fact that the redaction might be on an atom key instead of a string key
      name_value = Map.get(changeset, "name") || Map.get(changeset, :name)
      password_value = Map.get(changeset, "password") || Map.get(changeset, :password)

      assert name_value == "My password Redacted"
      assert password_value == "[REDACTED]"
    end

    test "logs changes when changeset is empty" do
      result =
        %Resource{}
        |> Changeset.change(%{})
        |> TestRepo.insert_and_log("cowboy")

      assert {:ok, %Resource{name: nil}} = result

      resource = TestRepo.one(Resource)
      resource_id = to_string(resource.id)

      assert %{
               changeset: changes,
               actor_id: "cowboy",
               resource_id: ^resource_id,
               resource: "resources",
               change_type: :insert
             } = TestRepo.one(Changelog)

      # For an empty changeset, nil password is OK
      assert Map.get(changes, "password") == nil
    end

    test "logs changes when changeset with embed is inserted" do
      attrs = %{
        name: "My name",
        array: ["apple", "banana"],
        map: %{longitude: 50.45000, latitude: 30.52333},
        data: %{key2: "key2"},
        category: %{"title" => "test"},
        comments: [
          %{"title" => "wow"},
          %{"title" => "very impressive"}
        ],
        items: [
          %{name: "Morgan"},
          %{name: "Freeman"}
        ]
      }

      result =
        %Resource{}
        |> Changeset.cast(attrs, [:name, :array, :map])
        |> Changeset.cast_embed(:data, with: &Resource.embed_changeset/2)
        |> Changeset.cast_embed(:items, with: &Resource.embeds_many_changeset/2)
        |> Changeset.cast_assoc(:category)
        |> Changeset.cast_assoc(:comments)
        |> TestRepo.insert_and_log("cowboy")

      assert {:ok, %Resource{name: "My name"}} = result

      resource = TestRepo.one(Resource)
      resource_id = to_string(resource.id)

      assert %{
               changeset: changes,
               actor_id: "cowboy",
               resource_id: ^resource_id,
               resource: "resources"
             } = TestRepo.one(Changelog)

      # Verify all expected fields
      expected = %{
        "name" => "My name",
        "data" => %{"key2" => "key2"},
        "category" => %{"title" => "test"},
        "comments" => [%{"title" => "wow"}, %{"title" => "very impressive"}],
        "items" => [%{"name" => "Morgan"}, %{"name" => "Freeman"}],
        "array" => ["apple", "banana"],
        "map" => %{"latitude" => 30.52333, "longitude" => 50.45}
      }

      # Check that all expected keys exist with correct values
      Enum.each(expected, fn {key, value} ->
        assert Map.get(changes, key) == value
      end)
    end

    test "returns error when changeset is invalid" do
      changeset =
        %Resource{}
        |> Changeset.change(%{name: "My name"})
        |> Changeset.add_error(:name, "invalid")

      result = TestRepo.insert_and_log(changeset, "cowboy")
      assert {:error, %Changeset{valid?: false}} = result

      assert [] == TestRepo.all(Resource)
      assert [] == TestRepo.all(Changelog)
    end
  end

  describe "update_and_log/3" do
    setup do
      {:ok, schema} = TestRepo.insert(%Resource{name: "name"})
      {:ok, %{schema: schema}}
    end

    test "logs changes when changeset is inserted", %{schema: schema} do
      result =
        schema
        |> Changeset.change(%{name: "My new name"})
        |> TestRepo.update_and_log("cowboy")

      assert {:ok, %Resource{name: "My new name"}} = result

      resource = TestRepo.one(Resource)
      resource_id = to_string(resource.id)

      assert %{
               changeset: %{"name" => "My new name"},
               actor_id: "cowboy",
               resource_id: ^resource_id,
               resource: "resources",
               change_type: :update
             } = TestRepo.one(Changelog)
    end

    test "returns error when changeset is invalid", %{schema: schema} do
      changeset =
        schema
        |> Changeset.change(%{name: "My new name"})
        |> Changeset.add_error(:name, "invalid")

      result = TestRepo.update_and_log(changeset, "cowboy")
      assert {:error, %Changeset{valid?: false}} = result

      assert [%{name: "name"}] = TestRepo.all(Resource)
      assert [] == TestRepo.all(Changelog)
    end
  end

  describe "upsert_and_log/3" do
    setup do
      {:ok, schema} = TestRepo.insert(%Resource{name: "name"})
      {:ok, %{schema: schema}}
    end

    test "logs changes when changeset is inserted", %{schema: schema} do
      result =
        schema
        |> Changeset.change(%{name: "My new name"})
        |> TestRepo.upsert_and_log("cowboy")

      assert {:ok, %Resource{name: "My new name"}} = result

      resource = TestRepo.one(Resource)
      resource_id = to_string(resource.id)

      assert %{
               changeset: %{"name" => "My new name"},
               actor_id: "cowboy",
               resource_id: ^resource_id,
               resource: "resources",
               change_type: :upsert
             } = TestRepo.one(Changelog)
    end
  end

  describe "use inside Ecto.Multi (prevents nested multi tx RuntimeError)" do
    test "insert_and_log succeeds and logs when invoked from a Multi.run step" do
      multi =
        Multi.new()
        |> Multi.run(:inserted, fn repo, _ ->
          repo.insert_and_log(%Resource{name: "multi insert"}, "multi-actor")
        end)

      assert {:ok, %{inserted: %Resource{name: "multi insert"}}} = TestRepo.transaction(multi)

      resource = TestRepo.one(from(r in Resource, where: r.name == "multi insert"))
      resource_id = to_string(resource.id)

      assert %{
               changeset: %{},
               actor_id: "multi-actor",
               resource_id: ^resource_id,
               resource: "resources",
               change_type: :insert
             } = TestRepo.one(Changelog)
    end

    test "update_and_log succeeds when invoked from within Multi" do
      {:ok, res} = TestRepo.insert(%Resource{name: "to-update"})

      multi =
        Multi.new()
        |> Multi.run(:updated, fn repo, _ ->
          res
          |> Changeset.change(%{name: "updated-in-multi"})
          |> repo.update_and_log("multi-actor")
        end)

      assert {:ok, %{updated: %Resource{name: "updated-in-multi"}}} = TestRepo.transaction(multi)

      assert TestRepo.exists?(
               from(c in Changelog, where: c.change_type == :update and c.actor_id == "multi-actor")
             )
    end

    test "upsert_and_log succeeds when invoked from within Multi" do
      {:ok, res} = TestRepo.insert(%Resource{name: "to-upsert"})

      multi =
        Multi.new()
        |> Multi.run(:upserted, fn repo, _ ->
          res
          |> Changeset.change(%{name: "upserted-in-multi"})
          |> repo.upsert_and_log("multi-actor")
        end)

      assert {:ok, %{upserted: %Resource{name: "upserted-in-multi"}}} =
               TestRepo.transaction(multi)

      assert TestRepo.exists?(
               from(c in Changelog, where: c.change_type == :upsert and c.actor_id == "multi-actor")
             )
    end

    test "delete_and_log succeeds when invoked from within Multi" do
      {:ok, res} = TestRepo.insert(%Resource{name: "to-delete"})

      multi =
        Multi.new()
        |> Multi.run(:deleted, fn repo, _ ->
          repo.delete_and_log(res, "multi-actor")
        end)

      assert {:ok, %{deleted: %Resource{name: "to-delete"}}} = TestRepo.transaction(multi)
      assert is_nil(TestRepo.get(Resource, res.id))

      assert TestRepo.exists?(
               from(c in Changelog, where: c.change_type == :delete and c.actor_id == "multi-actor")
             )
    end

    test "multiple sequential *_and_log calls inside one Multi" do
      {:ok, a} = TestRepo.insert(%Resource{name: "seq-a"})
      {:ok, b} = TestRepo.insert(%Resource{name: "seq-b"})

      multi =
        Multi.new()
        |> Multi.run(:update_a, fn repo, _ ->
          a |> Changeset.change(%{name: "seq-a-v2"}) |> repo.update_and_log("multi-actor")
        end)
        |> Multi.run(:update_b, fn repo, _ ->
          b |> Changeset.change(%{name: "seq-b-v2"}) |> repo.update_and_log("multi-actor")
        end)

      assert {:ok,
              %{
                update_a: %Resource{name: "seq-a-v2"},
                update_b: %Resource{name: "seq-b-v2"}
              }} = TestRepo.transaction(multi)

      assert 2 ==
               TestRepo.aggregate(
                 from(c in Changelog, where: c.actor_id == "multi-actor"),
                 :count
               )
    end
  end

  describe "unique pkey constraint on audit_log (OPS-4576)" do
    test "pkey collision on audit_log does not raise Ecto.ConstraintError; logging is best-effort and does not break the caller's tx" do
      # First operation creates the initial audit_log row (consumes the next serial PK value)
      assert {:ok, _first} =
               TestRepo.insert_and_log(%Resource{name: "first-for-pkey"}, "pkey-collision-actor")

      # Force the sequence so the *next* audit_log insert will collide on the pkey.
      # The repo migration uses default bigserial PK for the audit table -> sequence name is <table>_id_seq.
      Ecto.Adapters.SQL.query!(TestRepo, "ALTER SEQUENCE audit_log_id_seq RESTART WITH 1;")

      # This update_and_log will internally call log_changes -> repo.insert for the changelog row.
      # Before the fix this raises Ecto.ConstraintError (exactly as in the reported stack).
      # After the fix the unique_constraint declaration (or defensive rescue) turns it into a soft error;
      # the caller's transaction still commits successfully.
      result =
        TestRepo.transaction(fn ->
          {:ok, res} = TestRepo.insert(%Resource{name: "second-for-pkey"})

          res
          |> Changeset.change(%{name: "second-updated-under-collision"})
          |> TestRepo.update_and_log("pkey-collision-actor")
        end)

      assert {:ok, %Resource{name: "second-updated-under-collision"}} = result

      # At least one log for the actor must exist (the first one); the colliding log attempt must not have crashed the tx.
      assert TestRepo.aggregate(
               from(c in Changelog, where: c.actor_id == "pkey-collision-actor"),
               :count
             ) >= 1
    end
  end
end
