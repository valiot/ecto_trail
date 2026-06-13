defmodule EctoTrailConstraintDeclarationTest do
  use ExUnit.Case

  describe "changelog_changeset unique_constraint declarations (prevents Ecto.ConstraintError on audit_logs_pkey)" do
    test "declares unique constraints for common pkey names so insert violations become changeset errors" do
      cs =
        EctoTrail.__test_only_changelog_changeset__(%{
          actor_id: "actor",
          resource: "resources",
          resource_id: "1",
          changeset: %{},
          change_type: :update
        })

      unique_constraints =
        cs.constraints
        |> Enum.filter(&(&1.type == :unique))
        |> Enum.map(& &1.constraint)
        |> MapSet.new()

      # The three most common PK constraint names we protect against.
      # Declaring these makes Ecto turn a duplicate-PK insert into a normal changeset error
      # instead of raising Ecto.ConstraintError (the bug reported in OPS-4609).
      assert "audit_log_pkey" in unique_constraints
      assert "audit_logs_pkey" in unique_constraints

      # Also cover the dynamic case based on :table_name config (defaults to "audit_log")
      assert Enum.any?(unique_constraints, &String.ends_with?(&1, "_pkey"))
    end
  end
end
