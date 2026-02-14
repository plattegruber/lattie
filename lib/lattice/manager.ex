defmodule Lattice.Manager do
  @moduledoc """
  Manager loop — the core of Lattice.

  Reads constitution, initializes state, maintains backlog,
  proposes work via GitHub Issues, and scaffolds PRs upon approval.

  Supports run-once mode for Fly Scheduled Machines.
  """

  alias Lattice.{Constitution, EventLog, Backlog, Proposal, GitHub, Scaffold}

  @doc """
  Executes a single manager iteration.

  1. Initialize .lattice/ directory
  2. Load constitution
  3. Ensure backlog exists
  4. Select next task
  5. Create/check GitHub Issue
  6. Scaffold PR if approved
  """
  def run_once(opts \\ []) do
    root_dir = Keyword.get(opts, :root_dir, File.cwd!())
    opts = Keyword.put(opts, :root_dir, root_dir)

    with :ok <- init_lattice_dir(root_dir),
         {:ok, _} <- EventLog.append("manager_started", %{mode: "run_once"}, opts),
         {:ok, _constitution} <- load_constitution(root_dir, opts),
         {:ok, tasks} <- ensure_backlog(opts),
         {:ok, _} <- EventLog.append("backlog_loaded", %{task_count: length(tasks)}, opts),
         {:ok, task} <- select_next_task(opts),
         {:ok, result} <- process_task(task, opts),
         {:ok, _} <- EventLog.append("iteration_complete", %{result: format_result(result)}, opts) do
      {:ok, result}
    else
      {:error, reason} = err ->
        EventLog.append("manager_error", %{reason: inspect(reason)}, opts)
        err
    end
  end

  defp init_lattice_dir(root_dir) do
    lattice_dir = Path.join(root_dir, ".lattice")
    File.mkdir_p!(lattice_dir)
    File.mkdir_p!(Path.join(lattice_dir, "proposals"))
    File.mkdir_p!(Path.join(lattice_dir, "scaffolds"))
    :ok
  end

  defp load_constitution(root_dir, opts) do
    case Constitution.load(root_dir) do
      {:ok, docs} ->
        EventLog.append("constitution_loaded", %{files: Constitution.files()}, opts)
        {:ok, docs}

      {:error, _} = err ->
        err
    end
  end

  defp ensure_backlog(opts) do
    Backlog.ensure_exists(opts)
  end

  defp select_next_task(opts) do
    case Backlog.next_task(opts) do
      {:ok, nil} ->
        EventLog.append("backlog_empty", %{}, opts)
        {:error, :no_tasks}

      {:ok, task} ->
        EventLog.append("task_selected", %{task: task}, opts)
        {:ok, task}

      error ->
        error
    end
  end

  defp process_task(task, opts) do
    if GitHub.gh_available?() do
      process_task_with_github(task, opts)
    else
      process_task_local_only(task, opts)
    end
  end

  defp process_task_with_github(task, opts) do
    case GitHub.find_issue(task) do
      {:ok, [%{"number" => number} | _]} ->
        handle_existing_issue(task, number, opts)

      {:ok, _} ->
        create_proposal_and_issue(task, opts)
    end
  end

  defp handle_existing_issue(task, number, opts) do
    EventLog.append("issue_found", %{task: task, number: number}, opts)

    if GitHub.issue_approved?(number) do
      EventLog.append("issue_approved", %{task: task, number: number}, opts)

      {:ok, proposal} = Proposal.generate(task, opts)
      {:ok, scaffold} = Scaffold.generate(task, proposal, number, opts)

      EventLog.append(
        "scaffold_generated",
        %{task: task, branch: scaffold.branch},
        opts
      )

      {:ok, %{status: :scaffolded, task: task, issue: number, scaffold: scaffold}}
    else
      EventLog.append("awaiting_approval", %{task: task, number: number}, opts)
      {:ok, %{status: :awaiting_approval, task: task, issue: number}}
    end
  end

  defp create_proposal_and_issue(task, opts) do
    {:ok, proposal} = Proposal.generate(task, opts)
    EventLog.append("proposal_generated", %{task: task, file: proposal.filename}, opts)

    GitHub.ensure_labels(GitHub.required_labels())

    case GitHub.create_issue("[Lattice] #{task}", proposal.content, ["proposed"]) do
      {:ok, url} ->
        EventLog.append("issue_created", %{task: task, url: url}, opts)

        {:ok, %{status: :proposed, task: task, issue_url: url, proposal: proposal.filename}}

      {:skipped, reason} ->
        EventLog.append("issue_skipped", %{task: task, reason: reason}, opts)

        {:ok,
         %{
           status: :local_only,
           task: task,
           proposal: proposal.filename,
           reason: reason
         }}

      {:error, reason} ->
        EventLog.append("issue_failed", %{task: task, reason: inspect(reason)}, opts)

        {:ok,
         %{
           status: :local_only,
           task: task,
           proposal: proposal.filename,
           reason: inspect(reason)
         }}
    end
  end

  defp process_task_local_only(task, opts) do
    EventLog.append("github_unavailable", %{}, opts)

    {:ok, proposal} = Proposal.generate(task, opts)
    EventLog.append("proposal_generated", %{task: task, file: proposal.filename}, opts)

    {:ok,
     %{
       status: :local_only,
       task: task,
       proposal: proposal.filename,
       reason: "gh CLI not available"
     }}
  end

  defp format_result(%{status: status} = result) do
    result |> Map.put(:status, to_string(status)) |> Map.delete(:scaffold)
  end

  defp format_result(other), do: inspect(other)
end
