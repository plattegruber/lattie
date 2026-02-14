defmodule Mix.Tasks.Lattice.Run do
  @shortdoc "Run one Lattice manager iteration"
  @moduledoc """
  Runs the Lattice manager loop.

  ## Usage

      mix lattice.run           # Run one iteration
      mix lattice.run --loop    # Run continuously (30s interval)

  ## Environment Variables

      LATTICE_WRITE_ACTIONS=false   Disable all GitHub/Fly writes
      LATTICE_ENABLE_FLYCTL=false   Disable flyctl integration (default)

  In run-once mode (default), the manager:
  1. Loads the constitution
  2. Initializes .lattice/
  3. Ensures a backlog exists
  4. Selects the next task candidate
  5. Opens or updates a GitHub Issue for that task
  6. Waits for human approval
  7. Scaffolds PR structure once approved

  This mode is designed for Fly Scheduled Machines — start, iterate, exit.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, switches: [loop: :boolean])

    if opts[:loop] do
      run_loop()
    else
      run_once()
    end
  end

  defp run_once do
    IO.puts("Lattice manager: starting iteration...")

    case Lattice.Manager.run_once() do
      {:ok, result} ->
        IO.puts("Lattice manager: iteration complete")
        print_result(result)

      {:error, reason} ->
        IO.puts("Lattice manager: error — #{inspect(reason)}")
    end
  end

  defp run_loop do
    IO.puts("Lattice manager: continuous mode (Ctrl+C to stop)")

    Stream.repeatedly(fn ->
      run_once()
      IO.puts("\nNext iteration in 30 seconds...")
      Process.sleep(30_000)
    end)
    |> Stream.run()
  end

  defp print_result(%{status: :proposed} = r) do
    IO.puts("  Status:   proposed")
    IO.puts("  Task:     #{r.task}")
    IO.puts("  Issue:    #{r[:issue_url] || "N/A"}")
    IO.puts("  Proposal: #{r.proposal}")
    IO.puts("  -> Waiting for human approval on GitHub Issue")
  end

  defp print_result(%{status: :awaiting_approval} = r) do
    IO.puts("  Status: awaiting approval")
    IO.puts("  Task:   #{r.task}")
    IO.puts("  Issue:  ##{r.issue}")
    IO.puts("  -> Add 'approved' label to proceed")
  end

  defp print_result(%{status: :scaffolded} = r) do
    IO.puts("  Status: scaffolded")
    IO.puts("  Task:   #{r.task}")
    IO.puts("  Issue:  ##{r.issue}")
    IO.puts("  Branch: #{r.scaffold.branch}")
    IO.puts("  -> Ready for implementation")
  end

  defp print_result(%{status: :local_only} = r) do
    IO.puts("  Status:   local only (#{r.reason})")
    IO.puts("  Task:     #{r.task}")
    IO.puts("  Proposal: #{r.proposal}")
  end

  defp print_result(r) do
    IO.puts("  Result: #{inspect(r)}")
  end
end
