defmodule EctoTrailConstraintUnitTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Pure unit test (no DB, no sandbox) verifying that changelog_changeset/1
  declares unique_constraint/3 for the common pkey names that appear in
  customer prod schemas (audit_log_pkey, audit_logs_pkey, etc.).

  This is the regression test for OPS-4567: without these declarations,
  repo.insert of a Changelog inside *_and_log / log_changes raises
  Ecto.ConstraintError on unique pkey violation instead of turning it
  into a changeset error (which the existing rescue+log path already swallows).
  """

  test "changelog_changeset declares unique_constraint for common audit pkey names" do
    attrs = %{
      actor_id: "unit-actor",
      resource: "resources",
      resource_id: "42",
      changeset: %{},
      change_type: :insert
    }

    cs = EctoTrail.__build_changelog_changeset_for_test__(attrs)

    # The builder must have added constraints for the pkey names.
    constraint_names = Enum.map(cs.constraints, & &1.constraint)

    assert "audit_log_pkey" in constraint_names
    assert "audit_logs_pkey" in constraint_names

    # Sanity: the cast itself succeeded and the changeset is valid for insert.
    assert cs.valid?
    assert cs.data.__struct__ == EctoTrail.Changelog
  end

  test "changelog_changeset still produces valid changeset for normal attrs" do
    attrs = %{
      actor_id: "ok-actor",
      resource: "things",
      resource_id: "7",
      changeset: %{"foo" => "bar"},
      change_type: :upsert
    }

    cs = EctoTrail.__build_changelog_changeset_for_test__(attrs)
    assert cs.valid?
  end
end
