defmodule Lattice.GitHub do
  @moduledoc """
  GitHub integration via the `gh` CLI.

  GitHub is Lattice's human approval substrate:
  - Issues = intent approval
  - PRs = execution approval
  - Labels = state machine
  - Merges = commitment to reality

  All write operations respect LATTICE_WRITE_ACTIONS kill switch.
  """

  @labels ["proposed", "approved", "in-progress", "blocked", "done"]

  def required_labels, do: @labels

  @doc """
  Creates a GitHub Issue. Returns {:ok, url}, {:skipped, reason}, or {:error, reason}.
  """
  def create_issue(title, body, labels \\ []) do
    if not write_enabled?() do
      {:skipped, "LATTICE_WRITE_ACTIONS is disabled"}
    else
      args = ["issue", "create", "--title", title, "--body", body]
      args = args ++ Enum.flat_map(labels, &["--label", &1])

      case run_gh(args) do
        {output, 0} -> {:ok, String.trim(output)}
        {error, code} -> {:error, {code, error}}
      end
    end
  end

  @doc """
  Updates an existing GitHub Issue.
  """
  def update_issue(number, opts \\ []) do
    if not write_enabled?() do
      {:skipped, "LATTICE_WRITE_ACTIONS is disabled"}
    else
      args = ["issue", "edit", to_string(number)]
      args = args ++ if(opts[:title], do: ["--title", opts[:title]], else: [])
      args = args ++ if(opts[:body], do: ["--body", opts[:body]], else: [])
      args = args ++ Enum.flat_map(opts[:add_labels] || [], &["--add-label", &1])

      case run_gh(args) do
        {output, 0} -> {:ok, String.trim(output)}
        {error, code} -> {:error, {code, error}}
      end
    end
  end

  @doc """
  Searches for an existing issue by title.
  """
  def find_issue(title) do
    args = [
      "issue",
      "list",
      "--search",
      title,
      "--json",
      "number,title,labels,state",
      "--limit",
      "5"
    ]

    case run_gh(args) do
      {output, 0} ->
        case Lattice.Json.decode(String.trim(output)) do
          {:ok, issues} -> {:ok, issues}
          {:error, _} -> {:ok, []}
        end

      {_, _code} ->
        {:ok, []}
    end
  end

  @doc """
  Ensures all required labels exist in the repository.
  """
  def ensure_labels(labels) do
    if not write_enabled?() do
      {:skipped, "LATTICE_WRITE_ACTIONS is disabled"}
    else
      Enum.each(labels, fn label ->
        run_gh(["label", "create", label, "--force"])
      end)

      :ok
    end
  end

  @doc """
  Checks if an issue has the 'approved' label.
  """
  def issue_approved?(number) do
    args = ["issue", "view", to_string(number), "--json", "labels"]

    case run_gh(args) do
      {output, 0} ->
        case Lattice.Json.decode(String.trim(output)) do
          {:ok, %{"labels" => labels}} ->
            Enum.any?(labels, &(&1["name"] == "approved"))

          _ ->
            false
        end

      _ ->
        false
    end
  end

  @doc """
  Checks if `gh` CLI is available and authenticated.
  """
  def gh_available? do
    case System.find_executable("gh") do
      nil ->
        false

      _ ->
        case System.cmd("gh", ["auth", "status"], stderr_to_stdout: true) do
          {_, 0} -> true
          _ -> false
        end
    end
  end

  @doc """
  Returns true if write actions are enabled (LATTICE_WRITE_ACTIONS != "false").
  """
  def write_enabled? do
    System.get_env("LATTICE_WRITE_ACTIONS", "true") != "false"
  end

  defp run_gh(args) do
    cmd_fn = Application.get_env(:lattice, :system_cmd, &System.cmd/3)
    cmd_fn.("gh", args, stderr_to_stdout: true)
  end
end
