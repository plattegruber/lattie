defmodule Lattice.Scaffold do
  @moduledoc """
  Generates PR scaffolding once an Issue is approved.

  Produces:
  - Suggested branch name
  - PR template with vertical slice checklist
  - Links to proposal and Issue
  """

  @doc """
  Generates a PR scaffold for an approved task.
  Returns {:ok, scaffold}.
  """
  def generate(task, proposal, issue_number, opts \\ []) do
    root_dir = Keyword.get(opts, :root_dir, File.cwd!())

    branch_name = branch_for(task)
    pr_body = pr_template(task, proposal, issue_number)

    scaffold = %{
      branch: branch_name,
      pr_title: "[Lattice] #{truncate(task, 60)}",
      pr_body: pr_body,
      issue_number: issue_number,
      task: task
    }

    scaffold_dir = Path.join(root_dir, ".lattice/scaffolds")
    File.mkdir_p!(scaffold_dir)

    slug = slugify(task)
    path = Path.join(scaffold_dir, "#{slug}.md")
    File.write!(path, pr_body)

    {:ok, scaffold}
  end

  @doc """
  Generates a branch name for a task.
  """
  def branch_for(task) do
    "lattice/#{slugify(task)}"
  end

  defp pr_template(task, proposal, issue_number) do
    proposal_ref = if is_map(proposal), do: proposal[:filename], else: "See linked issue"

    """
    ## Summary

    #{task}

    Closes ##{issue_number}

    ## Proposal

    #{proposal_ref}

    ## Vertical Slice Checklist

    - [ ] Feature implementation
    - [ ] Tests (integration preferred)
    - [ ] Local dev verified (`mix lattice.run`)
    - [ ] CI passes
    - [ ] Documentation updated
    - [ ] Event log entries added for meaningful actions
    - [ ] No changes to constitutional documents

    ## Test Plan

    - [ ] `mix test` passes
    - [ ] Local end-to-end run succeeds
    - [ ] Event log contains expected entries
    """
    |> String.trim_leading()
  end

  defp slugify(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.slice(0, 50)
  end

  defp truncate(text, max) do
    if String.length(text) > max do
      String.slice(text, 0, max - 3) <> "..."
    else
      text
    end
  end
end
