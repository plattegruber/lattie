defmodule Lattice.EventLogTest do
  use ExUnit.Case, async: true

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "lattice_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    %{tmp_dir: tmp_dir}
  end

  test "appends events to log file", %{tmp_dir: tmp_dir} do
    assert {:ok, entry} =
             Lattice.EventLog.append("test_event", %{key: "value"}, root_dir: tmp_dir)

    assert entry.event == "test_event"
    assert entry.data == %{key: "value"}
    assert entry.ts != nil
  end

  test "creates .lattice directory if missing", %{tmp_dir: tmp_dir} do
    Lattice.EventLog.append("init", %{}, root_dir: tmp_dir)
    assert File.dir?(Path.join(tmp_dir, ".lattice"))
  end

  test "reads all events from log", %{tmp_dir: tmp_dir} do
    Lattice.EventLog.append("event_1", %{}, root_dir: tmp_dir)
    Lattice.EventLog.append("event_2", %{n: 2}, root_dir: tmp_dir)

    assert {:ok, events} = Lattice.EventLog.read_all(root_dir: tmp_dir)
    assert length(events) == 2
    assert Enum.at(events, 0)["event"] == "event_1"
    assert Enum.at(events, 1)["event"] == "event_2"
    assert Enum.at(events, 1)["data"]["n"] == 2
  end

  test "returns empty list for missing log", %{tmp_dir: tmp_dir} do
    assert {:ok, []} = Lattice.EventLog.read_all(root_dir: tmp_dir)
  end

  test "events are append-only and ordered", %{tmp_dir: tmp_dir} do
    Lattice.EventLog.append("first", %{}, root_dir: tmp_dir)
    Lattice.EventLog.append("second", %{}, root_dir: tmp_dir)
    Lattice.EventLog.append("third", %{}, root_dir: tmp_dir)

    {:ok, events} = Lattice.EventLog.read_all(root_dir: tmp_dir)
    assert length(events) == 3
    assert Enum.map(events, & &1["event"]) == ["first", "second", "third"]
  end

  test "each event has a timestamp", %{tmp_dir: tmp_dir} do
    Lattice.EventLog.append("timed", %{}, root_dir: tmp_dir)
    {:ok, [event]} = Lattice.EventLog.read_all(root_dir: tmp_dir)
    assert is_binary(event["ts"])
    assert {:ok, _, _} = DateTime.from_iso8601(event["ts"])
  end
end
