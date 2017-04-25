Application.put_env(:ex_unit, :capture_log, true)
Application.put_env(:ecto_trail, TestRepo,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: "ecto_trail_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 10)

defmodule TestRepo do
  use Ecto.Repo,
    otp_app: :ecto_trail,
    adapter: Ecto.Adapters.Postgres
  use EctoTrail
end

defmodule ResourcesSchema do
  @moduledoc false
  use Ecto.Schema

  schema "resources" do
    field :name, :string

    embeds_one :data, Data, primary_key: false do
      field :key1, :string
      field :key2, :string
    end

    timestamps()
  end

  def embed_changeset(schema, attrs) do
    schema
    |> Ecto.Changeset.cast(attrs, [:key1, :key2])
  end
end

# Start Postgrex
{:ok, _pids} = Application.ensure_all_started(:postgrex)

# Create DB
_ = TestRepo.__adapter__.storage_up(TestRepo.config)

# Start Repo
{:ok, _pid} = TestRepo.start_link()

# Migrate DB
migrations_path = Path.join([:code.priv_dir(:ecto_trail), "repo", "migrations"])
Ecto.Migrator.run(TestRepo, migrations_path, :up, all: true)

# Start ExUnit
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)
