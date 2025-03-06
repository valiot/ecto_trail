defmodule EctoTrail do
  @moduledoc """
  EctoTrail allows to store changeset changes into a separate `audit_log` table.

  ## Usage

  1. Add `ecto_trail` to your list of dependencies in `mix.exs`:

      def deps do
        [{:ecto_trail, "~> 0.1.0"}]
      end

  2. Ensure `ecto_trail` is started before your application:

    def application do
      [extra_applications: [:ecto_trail]]
    end

  3. Add a migration that creates `audit_log` table to `priv/repo/migrations` folder:

      defmodule EctoTrail.TestRepo.Migrations.CreateAuditLogTable do
        @moduledoc false
        use Ecto.Migration

        def change do
          create table(:audit_log, primary_key: false) do
            add :id, :uuid, primary_key: true
            add :actor_id, :string, null: false
            add :resource, :string, null: false
            add :resource_id, :string, null: false
            add :changeset, :map, null: false

            timestamps([type: :utc_datetime, updated_at: false])
          end
        end
      end

  4. Use `EctoTrail` in your repo:

      defmodule MyApp.Repo do
        use Ecto.Repo, otp_app: :my_app
        use EctoTrail
      end

  5. Use logging functions instead of defaults. See `EctoTrail` module docs.
  """
  alias Ecto.Changeset
  alias EctoTrail.Changelog
  alias Ecto.Multi
  require Logger

  @type action_type :: :insert | :update | :upsert | :delete

  # Cache frequently accessed config to avoid repeated lookups
  @redacted_fields_config Application.compile_env(:ecto_trail, :redacted_fields, nil)
  @changelog_fields [:actor_id, :resource, :resource_id, :changeset, :change_type]
  @not_loaded_pattern "Ecto.Association.NotLoaded"

  defmacro __using__(_) do
    quote do
      @type action_type :: :insert | :update | :upsert | :delete

      @doc """
      Store changes in a `change_log` table.
      """
      @spec log(
              struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
              changes :: Map.t(),
              actor_id :: String.T,
              action_type :: action_type()
            ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
      def log(struct_or_changeset, changes, actor_id, action_type),
        do: EctoTrail.log(__MODULE__, struct_or_changeset, changes, actor_id, action_type)

      @doc """
      Store bulk changes in a `change_log` table.
      """
      @spec log_bulk(
              structs :: list(Ecto.Schema.t()),
              changes :: list(Map.t()),
              actor_id :: String.T,
              action_type :: action_type()
            ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
      def log_bulk(structs, changes, actor_id, action_type),
        do: EctoTrail.log_bulk(__MODULE__, structs, changes, actor_id, action_type)

      @doc """
      Call `c:Ecto.Repo.insert/2` operation and store changes in a `change_log` table.

      Insert arguments, return and options same as `c:Ecto.Repo.insert/2` has.
      """
      @spec insert_and_log(
              struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
              actor_id :: String.T,
              opts :: Keyword.t()
            ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
      def insert_and_log(struct_or_changeset, actor_id, opts \\ []),
        do: EctoTrail.insert_and_log(__MODULE__, struct_or_changeset, actor_id, opts)

      @doc """
      Call `c:Ecto.Repo.update/2` operation and store changes in a `change_log` table.

      Insert arguments, return and options same as `c:Ecto.Repo.update/2` has.
      """
      @spec update_and_log(
              changeset :: Ecto.Changeset.t(),
              actor_id :: String.T,
              opts :: Keyword.t()
            ) ::
              {:ok, Ecto.Schema.t()}
              | {:error, Ecto.Changeset.t()}
      def update_and_log(changeset, actor_id, opts \\ []),
        do: EctoTrail.update_and_log(__MODULE__, changeset, actor_id, opts)

      @doc """
      Call `c:Ecto.Repo.upsert/2` operation and store changes in a `change_log` table.

      Insert arguments, return and options same as `c:Ecto.Repo.upsert/2` has.
      """
      @spec upsert_and_log(
              struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
              actor_id :: String.T,
              opts :: Keyword.t()
            ) ::
              {:ok, Ecto.Schema.t()}
              | {:error, Ecto.Changeset.t()}
      def upsert_and_log(struct_or_changeset, actor_id, opts \\ []),
        do: EctoTrail.upsert_and_log(__MODULE__, struct_or_changeset, actor_id, opts)

      @doc """
      Call `c:Ecto.Repo.delete/2` operation and store deleted objext in a `change_log` table.
      """
      @spec delete_and_log(
              struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
              actor_id :: String.T,
              opts :: Keyword.t()
            ) ::
              {:ok, Ecto.Schema.t()}
              | {:error, Ecto.Changeset.t()}
      def delete_and_log(struct_or_changeset, actor_id, opts \\ []),
        do: EctoTrail.delete_and_log(__MODULE__, struct_or_changeset, actor_id, opts)
    end
  end

  @doc """
  Store changes in a `change_log` table.
  """
  @spec log(
          repo :: Ecto.Repo.t(),
          struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
          changes :: Map.t(),
          actor_id :: String.T,
          action_type :: action_type()
        ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def log(repo, struct_or_changeset, changes, actor_id, action_type) do
    Multi.new()
    |> Multi.run(:operation, fn _, _ -> {:ok, struct_or_changeset} end)
    |> run_logging_transaction_alone(repo, struct_or_changeset, changes, actor_id, action_type)
  end

  @doc """
  Store bulk changes in a `change_log` table.
  """
  @spec log_bulk(
          repo :: Ecto.Repo.t(),
          structs :: list(Ecto.Schema.t()),
          changes :: list(Map.t()),
          actor_id :: String.T,
          action_type :: action_type()
        ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def log_bulk(repo, structs, changes, actor_id, action_type) do
    actor_id_str = to_actor_id_string(actor_id)

    Enum.zip(structs, changes)
    |> Enum.each(fn {struct, change} ->
      Multi.new()
      |> Multi.run(:operation, fn _, _ -> {:ok, struct} end)
      |> run_logging_transaction_alone(repo, struct, change, actor_id_str, action_type)
    end)
  end

  @doc """
  Call `c:Ecto.Repo.insert/2` operation and store changes in a `change_log` table.

  Insert arguments, return and options same as `c:Ecto.Repo.insert/2` has.
  """
  @spec insert_and_log(
          repo :: Ecto.Repo.t(),
          struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
          actor_id :: String.T,
          opts :: Keyword.t()
        ) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def insert_and_log(repo, struct_or_changeset, actor_id, opts \\ []) do
    Multi.new()
    |> Multi.insert(:operation, struct_or_changeset, opts)
    |> run_logging_transaction(repo, struct_or_changeset, actor_id, :insert)
  end

  @doc """
  Call `c:Ecto.Repo.update/2` operation and store changes in a `change_log` table.

  Insert arguments, return and options same as `c:Ecto.Repo.update/2` has.
  """
  @spec update_and_log(
          repo :: Ecto.Repo.t(),
          changeset :: Ecto.Changeset.t(),
          actor_id :: String.T,
          opts :: Keyword.t()
        ) ::
          {:ok, Ecto.Schema.t()}
          | {:error, Ecto.Changeset.t()}
  def update_and_log(repo, changeset, actor_id, opts \\ []) do
    Multi.new()
    |> Multi.update(:operation, changeset, opts)
    |> run_logging_transaction(repo, changeset, actor_id, :update)
  end

  @doc """
  Call `c:Ecto.Repo.upsert/2` operation and store changes in a `change_log` table.

  Insert arguments, return and options same as `c:Ecto.Repo.upsert/2` has.
  """
  @spec upsert_and_log(
          repo :: Ecto.Repo.t(),
          struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
          actor_id :: String.T,
          opts :: Keyword.t()
        ) ::
          {:ok, Ecto.Schema.t()}
          | {:error, Ecto.Changeset.t()}
  def upsert_and_log(repo, struct_or_changeset, actor_id, opts \\ []) do
    Multi.new()
    |> Multi.insert_or_update(:operation, struct_or_changeset, opts)
    |> run_logging_transaction(repo, struct_or_changeset, actor_id, :upsert)
  end

  @doc """
   Call `c:Ecto.Repo.delete/2` operation and store deleted objext in a `change_log` table.
  """
  @spec delete_and_log(
          repo :: Ecto.Repo.t(),
          struct_or_changeset :: Ecto.Schema.t() | Ecto.Changeset.t(),
          actor_id :: String.T,
          opts :: Keyword.t()
        ) ::
          {:ok, Ecto.Schema.t()}
          | {:error, Ecto.Changeset.t()}
  def delete_and_log(repo, struct_or_changeset, actor_id, opts \\ []) do
    Multi.new()
    |> Multi.delete(:operation, struct_or_changeset, opts)
    |> run_logging_transaction(repo, struct_or_changeset, actor_id, :delete)
  end

  defp run_logging_transaction(multi, repo, struct_or_changeset, actor_id, operation_type) do
    multi
    |> Multi.run(:changelog, &log_changes(&1, &2, struct_or_changeset, actor_id, operation_type))
    |> repo.transaction()
    |> build_result()
  end

  defp run_logging_transaction_alone(multi, repo, struct, changes, actor_id, operation_type) do
    multi
    |> Multi.run(
      :changelog,
      &log_changes_alone(&1, &2, struct, changes, actor_id, operation_type)
    )
    |> repo.transaction()
    |> build_result()
  end

  defp build_result({:ok, %{operation: operation}}), do: {:ok, operation}
  defp build_result({:error, :operation, reason, _changes_so_far}), do: {:error, reason}

  defp log_changes_alone(
         repo,
         %{operation: operation} = _multi_acc,
         _struct_or_changeset,
         changes,
         actor_id,
         operation_type
       ) do
    resource = operation.__struct__.__schema__(:source)
    actor_id_str = to_actor_id_string(actor_id)
    resource_id_str = to_string(operation.id)

    %{
      actor_id: actor_id_str,
      resource: resource,
      resource_id: resource_id_str,
      changeset: changes,
      change_type: operation_type
    }
    |> changelog_changeset()
    |> repo.insert()
    |> case do
      {:ok, changelog} ->
        {:ok, changelog}

      {:error, reason} ->
        Logger.error(
          "Failed to store changes in audit log: #{inspect(operation)} " <>
            "by actor #{inspect(actor_id)}. Reason: #{inspect(reason)}"
        )

        {:ok, reason}
    end
  end

  defp log_changes(repo, %{operation: operation} = _multi_acc, struct_or_changeset, actor_id, operation_type) do
    associations = operation.__struct__.__schema__(:associations)
    resource = operation.__struct__.__schema__(:source)
    embeds = operation.__struct__.__schema__(:embeds)

    struct_or_changeset = prepare_struct_or_changeset(struct_or_changeset, operation_type)

    changes =
      struct_or_changeset
      |> get_changes()
      |> get_embed_changes(embeds)
      |> get_assoc_changes(associations)
      |> redact_custom_fields()
      |> validate_changes(struct_or_changeset, operation_type)

    actor_id_str = to_actor_id_string(actor_id)
    resource_id_str = to_string(operation.id)

    %{
      actor_id: actor_id_str,
      resource: resource,
      resource_id: resource_id_str,
      changeset: changes,
      change_type: operation_type
    }
    |> changelog_changeset()
    |> repo.insert()
    |> case do
      {:ok, changelog} ->
        {:ok, changelog}

      {:error, reason} ->
        Logger.error(
          "Failed to store changes in audit log: #{inspect(struct_or_changeset)} " <>
            "by actor #{inspect(actor_id)}. Reason: #{inspect(reason)}"
        )

        {:ok, reason}
    end
  end

  defp prepare_struct_or_changeset(%Changeset{data: data} = _changeset, :delete), do: data
  defp prepare_struct_or_changeset(struct_or_changeset, _), do: struct_or_changeset

  defp to_actor_id_string(actor_id) when is_binary(actor_id), do: actor_id
  defp to_actor_id_string(actor_id), do: to_string(actor_id)

  defp validate_changes(_changes, schema, :delete) do
    # Special case for delete operations
    {_, return} =
      schema
      |> Map.from_struct()
      |> Map.pop(:__meta__)

    remove_empty_associations(return)
  end

  defp validate_changes(changes, _schema, _operation_type), do: changes

  defp redact_custom_fields(changeset) when is_nil(@redacted_fields_config), do: changeset
  defp redact_custom_fields(changeset), do: redact_fields(changeset, @redacted_fields_config)

  defp redact_fields(changeset, redacted_fields) do
    Enum.reduce(redacted_fields, changeset, fn field, acc ->
      Map.update(acc, field, nil, fn _ -> "[REDACTED]" end)
    end)
  end

  defp remove_empty_associations(struct) do
    struct
    |> Enum.map(fn
      {key, %{__struct__: _} = value} ->
        if not_loaded?(value), do: {key, nil}, else: {key, value}

      entry ->
        entry
    end)
    |> Map.new()
  end

  defp not_loaded?(value) do
    value
    |> Kernel.inspect()
    |> String.contains?(@not_loaded_pattern)
  end

  # Pattern matching for empty changeset
  defp get_changes(%Changeset{changes: changes}) when changes == %{}, do: %{}
  defp get_changes(%Changeset{changes: changes}), do: map_custom_ecto_types(changes)

  # Handle struct case
  defp get_changes(%{__struct__: _} = changes) do
    changes
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> map_custom_ecto_types()
    |> filter_nil_password()
  end

  # Handle regular map case
  defp get_changes(changes) when is_map(changes) do
    changes
    |> map_custom_ecto_types()
    |> filter_nil_password()
  end

  # Handle list case
  defp get_changes(changes) when is_list(changes) do
    Enum.map(changes, &get_changes/1)
  end

  # Handle other values (string, etc.)
  defp get_changes(value) do
    if not_loaded?(value), do: nil, else: value
  end

  defp filter_nil_password(changes) do
    case Map.get(changes, "password") do
      nil -> Map.delete(changes, "password")
      _ -> changes
    end
  end

  defp get_embed_changes(changeset, []), do: changeset

  defp get_embed_changes(changeset, embeds) do
    Enum.reduce(embeds, changeset, fn embed, acc ->
      case Map.get(acc, embed) do
        nil -> acc
        embed_changes -> Map.put(acc, embed, get_changes(embed_changes))
      end
    end)
  end

  defp get_assoc_changes(changeset, []), do: changeset

  defp get_assoc_changes(changeset, associations) do
    Enum.reduce(associations, changeset, fn assoc, acc ->
      case Map.get(acc, assoc) do
        nil ->
          acc

        assoc_changes when is_struct(assoc_changes) ->
          if not_loaded?(assoc_changes) do
            Map.put(acc, assoc, nil)
          else
            Map.put(acc, assoc, get_changes(assoc_changes))
          end

        assoc_changes ->
          Map.put(acc, assoc, get_changes(assoc_changes))
      end
    end)
  end

  defp map_custom_ecto_types(changes) do
    Map.new(changes, &map_custom_ecto_type/1)
  end

  defp map_custom_ecto_type({_field, %Changeset{}} = input), do: input
  defp map_custom_ecto_type({field, %{__struct__: _} = value}), do: {field, inspect(value)}

  defp map_custom_ecto_type({field, value}) when is_map(value) and is_map_key(value, :__struct__),
    do: {field, inspect(value)}

  defp map_custom_ecto_type({field, value}) when is_map(value), do: {field, value}
  defp map_custom_ecto_type(value), do: value

  defp changelog_changeset(attrs) do
    Changeset.cast(%Changelog{}, attrs, @changelog_fields)
  end
end
