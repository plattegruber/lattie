defmodule Lattice.ProposalTest do
  use ExUnit.Case, async: true

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "lattice_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    %{tmp_dir: tmp_dir}
  end

  test "generates proposal file on disk", %{tmp_dir: tmp_dir} do
    {:ok, proposal} = Lattice.Proposal.generate("Build worker agent framework", root_dir: tmp_dir)

    assert proposal.task == "Build worker agent framework"
    assert String.contains?(proposal.filename, "build-worker-agent-framework")
    assert String.ends_with?(proposal.filename, ".md")
    assert File.exists?(proposal.path)
  end

  test "proposal content matches task", %{tmp_dir: tmp_dir} do
    {:ok, proposal} = Lattice.Proposal.generate("Test task", root_dir: tmp_dir)
    assert proposal.content =~ "Test task"
  end

  test "proposal includes all required sections", %{tmp_dir: tmp_dir} do
    {:ok, proposal} = Lattice.Proposal.generate("Test task", root_dir: tmp_dir)

    assert proposal.content =~ "## Objective"
    assert proposal.content =~ "## Acceptance Criteria"
    assert proposal.content =~ "## Risks"
    assert proposal.content =~ "## Test Plan"
    assert proposal.content =~ "## Dev Impact"
    assert proposal.content =~ "## Docs Impact"
  end

  test "render produces valid markdown" do
    content = Lattice.Proposal.render("Some task")
    assert content =~ "# Proposal: Some task"
    assert content =~ "## Objective"
  end

  test "proposals are stored in .lattice/proposals/", %{tmp_dir: tmp_dir} do
    {:ok, proposal} = Lattice.Proposal.generate("Test", root_dir: tmp_dir)
    assert String.starts_with?(proposal.path, Path.join(tmp_dir, ".lattice/proposals/"))
  end
end
