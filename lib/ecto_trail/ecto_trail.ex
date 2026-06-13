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
  require Logger

  @type action_type :: :insert | :update | :upsert | :delete

  # Cache frequently accessed config to avoid repeated lookups
  @redacted_fields_config Application.compile_env(:ecto_trail, :redacted_fields, nil)
  @default_max_params 65_000
  @changelog_fields [:actor_id, :resource, :resource_id, :changeset, :change_type]
  @not_loaded_pattern "Ecto.Association.NotLoaded"
  @audit_log_table Application.compile_env(:ecto_trail, :table_name, "audit_log")

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
            ) :: {:ok, list(Ecto.Schema.t())} | {:error, Ecto.Changeset.t()}
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
    _ =
      log_changes_alone(
        repo,
        %{operation: struct_or_changeset},
        struct_or_changeset,
        changes,
        actor_id,
        action_type
      )

    {:ok, struct_or_changeset}
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
        ) :: {:ok, list(Ecto.Schema.t())} | {:error, Ecto.Changeset.t()}
  def log_bulk(_repo, [], _changes, _actor_id, _action_type), do: {:ok, []}

  def log_bulk(repo, structs, changes, actor_id, action_type) do
    actor_id_str = to_actor_id_string(actor_id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    changelog_entries = build_changelog_entries(structs, changes, actor_id_str, action_type, now)

    with :ok <- validate_changelog_entries(changelog_entries),
         inserted_count when is_integer(inserted_count) and inserted_count > 0 <-
           insert_all_chunks(repo, changelog_entries) do
      {:ok, structs}
    else
      {:error, changeset} ->
        {:error, changeset}

      :no_records_inserted ->
        {:error,
         Ecto.Changeset.add_error(
           %Ecto.Changeset{data: %Changelog{}},
           :base,
           "no records inserted"
         )}
    end
  rescue
    error ->
      Logger.error(
        "Failed to store bulk changes in audit log: #{inspect(structs)} " <>
          "by actor #{inspect(actor_id)}. Reason: #{inspect(error)}"
      )

      {:error, Ecto.Changeset.add_error(%Ecto.Changeset{data: %Changelog{}}, :base, Exception.message(error))}
  end

  # log_bulk/5 handles empty input before calling this helper.
  defp insert_all_chunks(repo, [_ | _] = entries) do
    chunk_size = max_rows_per_chunk(entries)

    # Let insert exceptions bubble to log_bulk/5's rescue so we keep a single error path.
    case repo.transaction(fn ->
           entries
           |> Enum.chunk_every(chunk_size)
           |> Enum.reduce(0, &insert_chunk(repo, &1, &2))
         end) do
      {:ok, count} -> count
      {:error, :no_records_inserted} -> :no_records_inserted
    end
  end

  defp insert_chunk(repo, chunk, acc) do
    case repo.insert_all(Changelog, chunk) do
      {count, _} when count > 0 -> acc + count
      {0, _} -> repo.rollback(:no_records_inserted)
    end
  end

  defp max_rows_per_chunk([first | _]) when map_size(first) > 0 do
    columns_count = map_size(first)
    max_params = Application.get_env(:ecto_trail, :max_params, @default_max_params)
    max(div(max_params, columns_count), 1)
  end

  defp max_rows_per_chunk([_ | _]), do: 1

  defp build_changelog_entries(structs, changes, actor_id_str, action_type, now) do
    Enum.zip(structs, changes)
    |> Enum.map(fn {struct, change} ->
      resource = struct.__struct__.__schema__(:source)
      resource_id_str = to_string(struct.id)

      attrs = %{
        actor_id: actor_id_str,
        resource: resource,
        resource_id: resource_id_str,
        changeset: change,
        change_type: action_type
      }

      changeset = changelog_changeset(attrs)

      if changeset.valid? do
        Map.put(changeset.changes, :inserted_at, now)
      else
        {:error, changeset}
      end
    end)
  end

  defp validate_changelog_entries(entries) do
    case Enum.find(entries, &match?({:error, _}, &1)) do
      {:error, _changeset} = error -> error
      nil -> :ok
    end
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
    repo.transaction(fn tx_repo ->
      case tx_repo.insert(struct_or_changeset, opts) do
        {:ok, operation} ->
          log_changes(tx_repo, %{operation: operation}, struct_or_changeset, actor_id, :insert)
          operation

        {:error, reason} ->
          tx_repo.rollback(reason)
      end
    end)
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
    repo.transaction(fn tx_repo ->
      case tx_repo.update(changeset, opts) do
        {:ok, operation} ->
          log_changes(tx_repo, %{operation: operation}, changeset, actor_id, :update)
          operation

        {:error, reason} ->
          tx_repo.rollback(reason)
      end
    end)
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
    repo.transaction(fn tx_repo ->
      case tx_repo.insert_or_update(struct_or_changeset, opts) do
        {:ok, operation} ->
          log_changes(tx_repo, %{operation: operation}, struct_or_changeset, actor_id, :upsert)
          operation

        {:error, reason} ->
          tx_repo.rollback(reason)
      end
    end)
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
    repo.transaction(fn tx_repo ->
      case tx_repo.delete(struct_or_changeset, opts) do
        {:ok, operation} ->
          log_changes(tx_repo, %{operation: operation}, struct_or_changeset, actor_id, :delete)
          operation

        {:error, reason} ->
          tx_repo.rollback(reason)
      end
    end)
  end

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
    |> insert_changelog_protected(repo)
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
    |> insert_changelog_protected(repo)
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
      # Handle both string and atom keys
      string_field = to_string(field)

      # Only redact if the field exists in the changeset
      if Map.has_key?(acc, field) or Map.has_key?(acc, string_field) do
        acc
        |> Map.put(field, "[REDACTED]")
        |> Map.put(string_field, "[REDACTED]")
      else
        acc
      end
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
  end

  # Handle regular map case
  defp get_changes(changes) when is_map(changes) do
    changes
    |> map_custom_ecto_types()
  end

  # Handle list case
  defp get_changes(changes) when is_list(changes) do
    Enum.map(changes, &get_changes/1)
  end

  # Handle other values (string, etc.)
  defp get_changes(value) do
    if not_loaded?(value), do: nil, else: value
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
        nil -> acc
        assoc_changes -> Map.put(acc, assoc, resolve_assoc_change(assoc_changes))
      end
    end)
  end

  defp resolve_assoc_change(assoc_changes) when is_struct(assoc_changes) do
    if not_loaded?(assoc_changes), do: nil, else: get_changes(assoc_changes)
  end

  defp resolve_assoc_change(assoc_changes), do: get_changes(assoc_changes)

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
    table = @audit_log_table

    %Changelog{}
    |> Changeset.cast(attrs, @changelog_fields)
    |> Changeset.unique_constraint(:id, name: "#{table}_pkey")
  end

  # Thin wrapper that turns *raised* DB errors (ConstraintError etc.) into {:error, e}
  # so callers can uniformly log+swallow audit write failures without letting them
  # abort the outer *_and_log transaction (see OPS-4565).
  defp insert_changelog_protected(changeset, repo) do
    try do
      repo.insert(changeset)
    rescue
      error -> {:error, error}
    end
  end
end
