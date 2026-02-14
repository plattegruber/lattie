defmodule Lattice.EventLog do
  @moduledoc """
  Append-only event log.

  Every meaningful action produces an immutable event entry.
  Events are stored as JSON lines in .lattice/events.log.
  """

  @log_file ".lattice/events.log"

  @doc """
  Appends an event to the log. Returns {:ok, entry}.
  """
  def append(event_type, data \\ %{}, opts \\ []) do
    root_dir = Keyword.get(opts, :root_dir, File.cwd!())
    path = Path.join(root_dir, @log_file)

    File.mkdir_p!(Path.dirname(path))

    entry = %{
      ts: DateTime.utc_now() |> DateTime.to_iso8601(),
      event: event_type,
      data: data
    }

    line = Lattice.Json.encode!(entry) <> "\n"
    File.write!(path, line, [:append])

    {:ok, entry}
  end

  @doc """
  Reads all events from the log. Returns {:ok, [event]} or {:error, reason}.
  """
  def read_all(opts \\ []) do
    root_dir = Keyword.get(opts, :root_dir, File.cwd!())
    path = Path.join(root_dir, @log_file)

    case File.read(path) do
      {:ok, content} ->
        events =
          content
          |> String.split("\n", trim: true)
          |> Enum.map(&Lattice.Json.decode!/1)

        {:ok, events}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
