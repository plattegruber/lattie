defmodule Lattice.BacklogTest do
  use ExUnit.Case, async: true

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "lattice_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    %{tmp_dir: tmp_dir}
  end

  test "creates initial backlog when missing", %{tmp_dir: tmp_dir} do
    assert {:ok, tasks} = Lattice.Backlog.init(root_dir: tmp_dir)
    assert is_list(tasks)
    assert length(tasks) > 0
    assert File.exists?(Path.join(tmp_dir, ".lattice/backlog.md"))
  end

  test "loads existing backlog", %{tmp_dir: tmp_dir} do
    {:ok, original} = Lattice.Backlog.init(root_dir: tmp_dir)
    assert {:ok, tasks} = Lattice.Backlog.load(root_dir: tmp_dir)
    assert is_list(tasks)
    assert tasks == original
  end

  test "returns nil for missing backlog", %{tmp_dir: tmp_dir} do
    assert {:ok, nil} = Lattice.Backlog.load(root_dir: tmp_dir)
  end

  test "ensure_exists creates if missing", %{tmp_dir: tmp_dir} do
    assert {:ok, tasks} = Lattice.Backlog.ensure_exists(root_dir: tmp_dir)
    assert length(tasks) > 0
  end

  test "ensure_exists preserves existing backlog", %{tmp_dir: tmp_dir} do
    {:ok, original} = Lattice.Backlog.init(root_dir: tmp_dir)
    {:ok, loaded} = Lattice.Backlog.ensure_exists(root_dir: tmp_dir)
    assert original == loaded
  end

  test "next_task returns first pending task", %{tmp_dir: tmp_dir} do
    {:ok, tasks} = Lattice.Backlog.init(root_dir: tmp_dir)
    {:ok, task} = Lattice.Backlog.next_task(root_dir: tmp_dir)
    assert task == List.first(tasks)
  end

  test "initial backlog is derived from constitution themes", %{tmp_dir: tmp_dir} do
    {:ok, tasks} = Lattice.Backlog.init(root_dir: tmp_dir)

    # Should contain agent/worker related tasks (from constitution)
    all_text = Enum.join(tasks, " ")
    assert all_text =~ "agent" or all_text =~ "worker" or all_text =~ "OTP"
  end

  test "backlog file is human-readable markdown", %{tmp_dir: tmp_dir} do
    Lattice.Backlog.init(root_dir: tmp_dir)
    content = File.read!(Path.join(tmp_dir, ".lattice/backlog.md"))
    assert content =~ "# Lattice Backlog"
    assert content =~ "- [ ] "
  end
end
