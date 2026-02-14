defmodule Lattice.ScaffoldTest do
  use ExUnit.Case, async: true

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "lattice_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    %{tmp_dir: tmp_dir}
  end

  test "generates PR scaffold", %{tmp_dir: tmp_dir} do
    proposal = %{filename: "20240101-0000-test-task.md"}
    {:ok, scaffold} = Lattice.Scaffold.generate("Test task", proposal, 42, root_dir: tmp_dir)

    assert scaffold.branch =~ "lattice/"
    assert scaffold.pr_title =~ "Test task"
    assert scaffold.issue_number == 42
    assert scaffold.pr_body =~ "Closes #42"
  end

  test "branch_for generates valid branch names" do
    assert Lattice.Scaffold.branch_for("Build worker framework") ==
             "lattice/build-worker-framework"
  end

  test "scaffold includes vertical slice checklist", %{tmp_dir: tmp_dir} do
    proposal = %{filename: "test.md"}
    {:ok, scaffold} = Lattice.Scaffold.generate("Task", proposal, 1, root_dir: tmp_dir)

    assert scaffold.pr_body =~ "Feature implementation"
    assert scaffold.pr_body =~ "Tests"
    assert scaffold.pr_body =~ "Local dev"
    assert scaffold.pr_body =~ "CI passes"
    assert scaffold.pr_body =~ "Documentation"
    assert scaffold.pr_body =~ "Event log"
    assert scaffold.pr_body =~ "constitutional documents"
  end

  test "scaffold writes file to .lattice/scaffolds/", %{tmp_dir: tmp_dir} do
    proposal = %{filename: "test.md"}
    Lattice.Scaffold.generate("My task", proposal, 1, root_dir: tmp_dir)

    scaffolds = File.ls!(Path.join(tmp_dir, ".lattice/scaffolds"))
    assert length(scaffolds) == 1
  end

  test "long task names are truncated in PR title", %{tmp_dir: tmp_dir} do
    long_task = String.duplicate("a", 100)
    proposal = %{filename: "test.md"}
    {:ok, scaffold} = Lattice.Scaffold.generate(long_task, proposal, 1, root_dir: tmp_dir)

    assert String.length(scaffold.pr_title) < 80
  end
end
