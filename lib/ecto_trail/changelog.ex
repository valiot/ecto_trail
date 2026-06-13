defmodule EctoTrail.Changelog do
  @moduledoc """
  This is schema that used to store changes in DB.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @table_name Application.compile_env(:ecto_trail, :table_name, "audit_log")
  @pkey_name :"#{@table_name}_pkey"

  schema @table_name do
    field(:actor_id, :string)
    field(:resource, :string)
    field(:resource_id, :string)
    field(:changeset, :map)
    field(:change_type, EctoTrailChangeEnum)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @changelog_fields [:actor_id, :resource, :resource_id, :changeset, :change_type]

  @doc """
  Changeset used for inserting audit log rows.

  Attaches a unique_constraint on the primary key name (derived from the
  configured table name, default "audit_log_pkey") so that a duplicate-key
  race does not raise Ecto.ConstraintError; instead the insert returns
  `{:error, changeset}` which the call sites already treat as a soft failure
  (they log and continue, never rolling back the caller's outer transaction).
  """
  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(attrs) do
    cast(%__MODULE__{}, attrs, @changelog_fields)
    |> unique_constraint(:id, name: @pkey_name)
  end
end
