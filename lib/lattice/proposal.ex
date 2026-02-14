defmodule Lattice.Proposal do
  @moduledoc """
  Generates proposal documents for task candidates.

  Each proposal is a markdown file in .lattice/proposals/ containing:
  objective, acceptance criteria, risks, test plan, dev impact, docs impact.
  """

  @doc """
  Generates a proposal file for the given task.
  Returns {:ok, %{path, filename, content, task}}.
  """
  def generate(task, opts \\ []) do
    root_dir = Keyword.get(opts, :root_dir, File.cwd!())
    proposals_dir = Path.join(root_dir, ".lattice/proposals")
    File.mkdir_p!(proposals_dir)

    timestamp = format_timestamp(DateTime.utc_now())
    slug = slugify(task)
    filename = "#{timestamp}-#{slug}.md"
    path = Path.join(proposals_dir, filename)

    content = render(task)
    File.write!(path, content)

    {:ok, %{path: path, filename: filename, content: content, task: task}}
  end

  @doc """
  Renders proposal markdown for a given task.
  """
  def render(task) do
    """
    # Proposal: #{task}

    ## Objective

    #{task}

    Derived from Lattice constitution analysis.

    ## Acceptance Criteria

    - [ ] Implementation complete
    - [ ] Tests pass (integration preferred over mocks)
    - [ ] Local dev works with single command
    - [ ] Documentation updated
    - [ ] Event log entries for all meaningful actions

    ## Risks

    - Scope creep beyond vertical slice
    - Missing integration test coverage
    - Breaking existing manager loop

    ## Test Plan

    - Unit tests for new module
    - Integration test with manager loop
    - Local end-to-end verification

    ## Dev Impact

    - New module(s) in lib/lattice/
    - New test(s) in test/lattice/
    - Possible config changes

    ## Docs Impact

    - README update if public-facing
    - No changes to constitutional documents
    """
    |> String.trim_leading()
  end

  defp format_timestamp(dt) do
    dt
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
    |> String.slice(0, 16)
    |> String.replace(~r/[^0-9]/, "")
    |> String.slice(0, 12)
    |> then(fn s ->
      date = String.slice(s, 0, 8)
      time = String.slice(s, 8, 4)
      "#{date}-#{time}"
    end)
  end

  defp slugify(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.slice(0, 50)
  end
end
