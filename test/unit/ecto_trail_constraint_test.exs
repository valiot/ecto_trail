defmodule EctoTrailConstraintTest do
  # Pure unit test - no DB, no DataCase, no repo started.
  use ExUnit.Case, async: true

  alias Ecto.Changeset

  describe "audit_log pkey unique constraint handling" do
    test "changelog_changeset declares unique_constraint on :id using the pkey name" do
      attrs = %{
        actor_id: "actor",
        resource: "resources",
        resource_id: "1",
        changeset: %{"name" => "x"},
        change_type: :update
      }

      cs = EctoTrail.__changelog_changeset_for_test__(attrs)

      assert %Changeset{} = cs

      assert Enum.any?(cs.constraints, fn c ->
               c.field == :id and c.type == :unique and
                 String.contains?(to_string(c.constraint), "pkey")
             end),
             "expected unique_constraint for :id (pkey) to be declared on the changeset, got: #{inspect(cs.constraints)}"
    end
  end
end
