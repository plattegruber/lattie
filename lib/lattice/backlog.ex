defmodule Lattice.Backlog do
  @moduledoc """
  Manages the human-readable backlog file at .lattice/backlog.md.

  Generates an initial backlog derived from the constitutional documents
  if none exists. Tasks are deterministically ordered.
  """

  @backlog_file ".lattice/backlog.md"

  @initial_tasks [
    "Implement OTP supervision tree for agent lifecycle",
    "Add persistent state storage for agent memory",
    "Build worker agent framework with bounded task execution",
    "Implement scout agents for external signal monitoring",
    "Add operator notification system for proactive summaries",
    "Implement intent decomposition from natural language goals",
    "Build status reporting interface (CLI)",
    "Add Clerk authentication integration stub",
    "Implement ambient scheduling for background operations",
    "Add property-based tests for agent recovery scenarios"
  ]

  @doc """
  Loads the backlog file. Returns {:ok, [task]} or {:ok, nil} if missing.
  """
  def load(opts \\ []) do
    root_dir = Keyword.get(opts, :root_dir, File.cwd!())
    path = Path.join(root_dir, @backlog_file)

    case File.read(path) do
      {:ok, content} -> {:ok, parse(content)}
      {:error, :enoent} -> {:ok, nil}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates the initial backlog file derived from constitution analysis.
  """
  def init(opts \\ []) do
    root_dir = Keyword.get(opts, :root_dir, File.cwd!())
    path = Path.join(root_dir, @backlog_file)

    File.mkdir_p!(Path.dirname(path))

    content = render(@initial_tasks)
    File.write!(path, content)

    {:ok, @initial_tasks}
  end

  @doc """
  Ensures backlog exists, creating it if missing.
  """
  def ensure_exists(opts \\ []) do
    case load(opts) do
      {:ok, nil} -> init(opts)
      {:ok, tasks} -> {:ok, tasks}
      error -> error
    end
  end

  @doc """
  Returns the next pending task (first item). Deterministic selection.
  """
  def next_task(opts \\ []) do
    case ensure_exists(opts) do
      {:ok, [task | _]} -> {:ok, task}
      {:ok, []} -> {:ok, nil}
      error -> error
    end
  end

  def initial_tasks, do: @initial_tasks

  defp parse(content) do
    content
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "- [ ] "))
    |> Enum.map(fn line ->
      String.replace_prefix(line, "- [ ] ", "")
    end)
  end

  defp render(tasks) do
    header = """
    # Lattice Backlog

    Generated from constitution analysis.
    Ordered by priority. First pending task is the next candidate.

    """

    items = Enum.map_join(tasks, "\n", &("- [ ] " <> &1))
    String.trim_leading(header) <> items <> "\n"
  end
end
