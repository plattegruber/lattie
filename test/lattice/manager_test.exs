defmodule Lattice.ManagerTest do
  use ExUnit.Case

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "lattice_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(tmp_dir, "docs"))

    File.write!(
      Path.join(tmp_dir, "docs/product-directive.md"),
      "# Product Directive\nLattice is a personal autonomous systems layer."
    )

    File.write!(
      Path.join(tmp_dir, "docs/technical-opinion.md"),
      "# Technical Opinion\nPrimary runtime: Elixir."
    )

    old_write = System.get_env("LATTICE_WRITE_ACTIONS")
    System.put_env("LATTICE_WRITE_ACTIONS", "false")

    on_exit(fn ->
      File.rm_rf!(tmp_dir)

      if old_write do
        System.put_env("LATTICE_WRITE_ACTIONS", old_write)
      else
        System.delete_env("LATTICE_WRITE_ACTIONS")
      end

      Application.delete_env(:lattice, :system_cmd)
    end)

    %{tmp_dir: tmp_dir}
  end

  test "run_once completes full iteration", %{tmp_dir: tmp_dir} do
    assert {:ok, result} = Lattice.Manager.run_once(root_dir: tmp_dir)
    assert result.status in [:proposed, :local_only, :awaiting_approval, :scaffolded]
    assert result.task != nil
  end

  test "creates .lattice directory structure", %{tmp_dir: tmp_dir} do
    Lattice.Manager.run_once(root_dir: tmp_dir)
    assert File.dir?(Path.join(tmp_dir, ".lattice"))
    assert File.dir?(Path.join(tmp_dir, ".lattice/proposals"))
    assert File.dir?(Path.join(tmp_dir, ".lattice/scaffolds"))
  end

  test "creates event log with entries", %{tmp_dir: tmp_dir} do
    Lattice.Manager.run_once(root_dir: tmp_dir)
    log_path = Path.join(tmp_dir, ".lattice/events.log")
    assert File.exists?(log_path)

    {:ok, events} = Lattice.EventLog.read_all(root_dir: tmp_dir)
    assert length(events) > 0
  end

  test "creates backlog if missing", %{tmp_dir: tmp_dir} do
    Lattice.Manager.run_once(root_dir: tmp_dir)
    assert File.exists?(Path.join(tmp_dir, ".lattice/backlog.md"))
  end

  test "generates proposal for selected task", %{tmp_dir: tmp_dir} do
    Lattice.Manager.run_once(root_dir: tmp_dir)
    proposals = File.ls!(Path.join(tmp_dir, ".lattice/proposals"))
    assert length(proposals) > 0
  end

  test "event log contains expected lifecycle events", %{tmp_dir: tmp_dir} do
    Lattice.Manager.run_once(root_dir: tmp_dir)
    {:ok, events} = Lattice.EventLog.read_all(root_dir: tmp_dir)

    event_types = Enum.map(events, & &1["event"])
    assert "manager_started" in event_types
    assert "constitution_loaded" in event_types
    assert "backlog_loaded" in event_types
    assert "task_selected" in event_types
    assert "iteration_complete" in event_types
  end

  test "multiple iterations are idempotent on task selection", %{tmp_dir: tmp_dir} do
    {:ok, result1} = Lattice.Manager.run_once(root_dir: tmp_dir)
    {:ok, result2} = Lattice.Manager.run_once(root_dir: tmp_dir)

    assert result1.task == result2.task
  end

  test "returns error when constitution is missing" do
    empty_dir =
      Path.join(System.tmp_dir!(), "lattice_empty_#{System.unique_integer([:positive])}")

    File.mkdir_p!(empty_dir)
    assert {:error, _} = Lattice.Manager.run_once(root_dir: empty_dir)
    File.rm_rf!(empty_dir)
  end

  test "handles github unavailable gracefully", %{tmp_dir: tmp_dir} do
    {:ok, result} = Lattice.Manager.run_once(root_dir: tmp_dir)
    # Without gh CLI configured, should fall back to local_only
    assert result.status == :local_only
    assert result.reason != nil
  end
end
