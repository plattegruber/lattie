defmodule Lattice.Fly do
  @moduledoc """
  Flyctl capability module with safety controls.

  - LATTICE_ENABLE_FLYCTL=false by default
  - Command allowlist (no arbitrary flyctl usage)
  - SAFE commands: read-only operations
  - CONTROLLED commands: require GitHub Issue approval
  - All flyctl usage logged to event log
  - Auth via FLY_ACCESS_TOKEN
  """

  @safe_commands ~w(status list info logs)
  @controlled_commands ~w(deploy scale secrets machine)

  def safe_commands, do: @safe_commands
  def controlled_commands, do: @controlled_commands

  @doc """
  Returns true if flyctl integration is enabled.
  """
  def enabled? do
    System.get_env("LATTICE_ENABLE_FLYCTL", "false") == "true"
  end

  @doc """
  Executes a flyctl command with safety checks.

  Options:
    - :approved - set to true for CONTROLLED commands that have Issue approval
    - :root_dir - root directory for event log
  """
  def run(command, args \\ [], opts \\ []) do
    cond do
      not enabled?() ->
        {:error, :flyctl_disabled}

      not command_allowed?(command) ->
        {:error, {:command_not_allowed, command}}

      controlled?(command) and not Keyword.get(opts, :approved, false) ->
        {:error, {:approval_required, command}}

      true ->
        log_opts = Keyword.take(opts, [:root_dir])

        Lattice.EventLog.append(
          "flyctl_executed",
          %{command: command, args: args, safe: safe?(command)},
          log_opts
        )

        execute(command, args)
    end
  end

  @doc "Returns true if the command is in the safe (read-only) list."
  def safe?(command), do: command in @safe_commands

  @doc "Returns true if the command is in the controlled (write) list."
  def controlled?(command), do: command in @controlled_commands

  @doc "Returns true if the command is on any allowlist."
  def command_allowed?(command), do: safe?(command) or controlled?(command)

  defp execute(command, args) do
    full_args = [command | args]
    cmd_fn = Application.get_env(:lattice, :system_cmd, &System.cmd/3)

    case cmd_fn.("flyctl", full_args, stderr_to_stdout: true, env: fly_env()) do
      {output, 0} -> {:ok, String.trim(output)}
      {error, code} -> {:error, {code, error}}
    end
  end

  defp fly_env do
    case System.get_env("FLY_ACCESS_TOKEN") do
      nil -> []
      token -> [{"FLY_ACCESS_TOKEN", token}]
    end
  end
end
