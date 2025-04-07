# Usage: mix run benchmark/ecto_trail_benchmark.exs
# Compare with main branch by running the same script on both branches

# Enable test environment
Mix.env(:test)

# Start the test repo
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)

alias EctoTrail.TestRepo
alias Ecto.Changeset

# Ensure the repo is started and create tables
TestRepo.start_link()

defmodule EctoTrailBench do
  @moduledoc """
  Performance benchmarks for EctoTrail operations.
  """

  def setup do
    # Clean up any existing data
    cleanup()

    # Create test data
    create_test_resources()
  end

  def cleanup do
    # Drop and recreate tables
    Enum.each(
      ~w(audit_log resources categories comments),
      fn table ->
        TestRepo.query!("TRUNCATE #{table} RESTART IDENTITY CASCADE")
      end
    )
  end

  def create_test_resources do
    # Create test resources of various sizes for benchmarking
    Enum.each(1..100, fn i ->
      %Resource{name: "Resource #{i}"}
      |> TestRepo.insert!()
    end)
  end

  # Benchmark scenarios

  # 1. Simple insert with a small changeset
  def simple_insert(actor_id) do
    %Resource{}
    |> Changeset.change(%{name: "Simple Insert Test"})
    |> TestRepo.insert_and_log(actor_id)
  end

  # 2. Insert with a large changeset
  def complex_insert(actor_id) do
    attrs = %{
      name: "Complex Insert Test",
      array: Enum.map(1..50, &"Item #{&1}"),
      map: Enum.into(1..50, %{}, fn i -> {"key_#{i}", "value_#{i}"} end),
      data: %{key1: "Large value 1", key2: "Large value 2"},
      category: %{"title" => "Test Category"},
      comments: Enum.map(1..20, fn i -> %{"title" => "Comment #{i}"} end),
      items: Enum.map(1..20, fn i -> %{name: "Item #{i}"} end)
    }

    %Resource{}
    |> Changeset.cast(attrs, [:name, :array, :map])
    |> Changeset.cast_embed(:data, with: &Resource.embed_changeset/2)
    |> Changeset.cast_embed(:items, with: &Resource.embeds_many_changeset/2)
    |> Changeset.cast_assoc(:category)
    |> Changeset.cast_assoc(:comments)
    |> TestRepo.insert_and_log(actor_id)
  end

  # 3. Update with a small changeset
  def simple_update(actor_id) do
    resource = TestRepo.get(Resource, 1)

    resource
    |> Changeset.change(%{name: "Updated Simple #{:rand.uniform(1000)}"})
    |> TestRepo.update_and_log(actor_id)
  end

  # 4. Update with a large changeset
  def complex_update(actor_id) do
    resource = TestRepo.get(Resource, 2)

    attrs = %{
      name: "Updated Complex #{:rand.uniform(1000)}",
      array: Enum.map(1..50, &"Updated Item #{&1}"),
      map: Enum.into(1..50, %{}, fn i -> {"updated_key_#{i}", "updated_value_#{i}"} end)
    }

    resource
    |> Changeset.cast(attrs, [:name, :array, :map])
    |> TestRepo.update_and_log(actor_id)
  end

  # 5. Delete operation
  def delete_resource(actor_id) do
    resource = TestRepo.get(Resource, 3)
    TestRepo.delete_and_log(resource, actor_id)
  end

  # 6. Bulk operations (10 items)
  def bulk_operations(actor_id) do
    resources = TestRepo.all(Resource, limit: 10)
    changes = Enum.map(resources, fn _ -> %{updated_at: DateTime.utc_now()} end)
    TestRepo.log_bulk(resources, changes, actor_id, :update)
  end

  # 7. Insert with redacted fields
  def insert_with_redaction(actor_id) do
    %Resource{}
    |> Changeset.change(%{
      name: "Redaction Test",
      password: "secret_password_#{:rand.uniform(1000)}"
    })
    |> TestRepo.insert_and_log(actor_id)
  end

  # 8. Test with different data types for actor_id
  def insert_with_atom_actor(actor_id) when is_atom(actor_id) do
    %Resource{}
    |> Changeset.change(%{name: "Atom Actor Test"})
    |> TestRepo.insert_and_log(actor_id)
  end

  def insert_with_integer_actor(actor_id) when is_integer(actor_id) do
    %Resource{}
    |> Changeset.change(%{name: "Integer Actor Test"})
    |> TestRepo.insert_and_log(actor_id)
  end
end

# Setup benchmark data
IO.puts("Setting up benchmark data...")
EctoTrailBench.setup()

# Run the benchmarks
IO.puts("Running EctoTrail performance benchmarks...")

Benchee.run(
  %{
    "Simple insert" => fn -> EctoTrailBench.simple_insert("user_1") end,
    "Complex insert" => fn -> EctoTrailBench.complex_insert("user_2") end,
    "Simple update" => fn -> EctoTrailBench.simple_update("user_3") end,
    "Complex update" => fn -> EctoTrailBench.complex_update("user_4") end,
    "Delete operation" => fn -> EctoTrailBench.delete_resource("user_5") end,
    "Bulk operations" => fn -> EctoTrailBench.bulk_operations("user_6") end,
    "Insert with redaction" => fn -> EctoTrailBench.insert_with_redaction("user_7") end,
    "Insert with atom actor" => fn -> EctoTrailBench.insert_with_atom_actor(:user_8) end,
    "Insert with integer actor" => fn -> EctoTrailBench.insert_with_integer_actor(9) end
  },
  time: 5,
  memory_time: 2,
  warmup: 1,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmark_results.html", auto_open: false}
  ],
  print: [
    benchmarking: true,
    configuration: true,
    fast_warning: true
  ]
)

# Clean up after benchmarks
IO.puts("Cleaning up benchmark data...")
EctoTrailBench.cleanup()
