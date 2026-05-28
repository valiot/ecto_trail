defmodule EctoTrailTest do
  use EctoTrail.DataCase
  alias EctoTrail.Changelog
  alias Ecto.Changeset
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

  describe "Ecto.Multi compose support (avoids nested tx + unexpected rollback)" do
    test "insert_and_log/5 can be piped into multi and executes atomically with log" do
      multi =
        Ecto.Multi.new()
        |> TestRepo.insert_and_log(:res, %Resource{name: "multi-name"}, "multi-actor", [])

      assert {:ok, results} = TestRepo.transaction(multi)
      assert %Resource{name: "multi-name"} = results[:res]
      changelog = TestRepo.one(Changelog)
      assert changelog.actor_id == "multi-actor"
      assert changelog.change_type == :insert
      assert changelog.resource == "resources"
    end

    test "update_and_log/5 and delete_and_log/5 work when composed into multi" do
      {:ok, inserted} = TestRepo.insert(%Resource{name: "to-update"})

      multi =
        Ecto.Multi.new()
        |> TestRepo.update_and_log(:upd, Changeset.change(inserted, %{name: "updated"}), "multi-actor", [])
        |> TestRepo.delete_and_log(:del, inserted, "multi-actor", [])

      assert {:ok, results} = TestRepo.transaction(multi)
      assert %Resource{name: "updated"} = results[:upd]
      assert %Resource{} = results[:del]
      logs = TestRepo.all(Changelog)
      assert length(logs) == 2
      assert Enum.any?(logs, &(&1.change_type == :update and &1.actor_id == "multi-actor"))
      assert Enum.any?(logs, &(&1.change_type == :delete and &1.actor_id == "multi-actor"))
    end
  end
end
