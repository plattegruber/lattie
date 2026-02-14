defmodule Lattice.GitHubTest do
  use ExUnit.Case

  setup do
    old_write = System.get_env("LATTICE_WRITE_ACTIONS")

    on_exit(fn ->
      if old_write do
        System.put_env("LATTICE_WRITE_ACTIONS", old_write)
      else
        System.delete_env("LATTICE_WRITE_ACTIONS")
      end

      Application.delete_env(:lattice, :system_cmd)
    end)

    :ok
  end

  test "write_enabled? returns false when LATTICE_WRITE_ACTIONS=false" do
    System.put_env("LATTICE_WRITE_ACTIONS", "false")
    refute Lattice.GitHub.write_enabled?()
  end

  test "write_enabled? returns true when LATTICE_WRITE_ACTIONS=true" do
    System.put_env("LATTICE_WRITE_ACTIONS", "true")
    assert Lattice.GitHub.write_enabled?()
  end

  test "write_enabled? defaults to true when env not set" do
    System.delete_env("LATTICE_WRITE_ACTIONS")
    assert Lattice.GitHub.write_enabled?()
  end

  test "create_issue skips when writes disabled" do
    System.put_env("LATTICE_WRITE_ACTIONS", "false")
    assert {:skipped, _} = Lattice.GitHub.create_issue("Test", "Body")
  end

  test "update_issue skips when writes disabled" do
    System.put_env("LATTICE_WRITE_ACTIONS", "false")
    assert {:skipped, _} = Lattice.GitHub.update_issue(1, title: "Updated")
  end

  test "ensure_labels skips when writes disabled" do
    System.put_env("LATTICE_WRITE_ACTIONS", "false")
    assert {:skipped, _} = Lattice.GitHub.ensure_labels(["proposed"])
  end

  test "create_issue calls gh with correct args when writes enabled" do
    System.put_env("LATTICE_WRITE_ACTIONS", "true")

    test_pid = self()

    Application.put_env(:lattice, :system_cmd, fn "gh", args, _opts ->
      send(test_pid, {:gh_called, args})
      {"https://github.com/test/issues/1", 0}
    end)

    assert {:ok, url} = Lattice.GitHub.create_issue("Title", "Body", ["proposed"])
    assert url =~ "github.com"

    assert_received {:gh_called, args}
    assert "issue" in args
    assert "create" in args
    assert "--title" in args
    assert "proposed" in args
  end

  test "find_issue parses gh output" do
    Application.put_env(:lattice, :system_cmd, fn "gh", _args, _opts ->
      {~s([{"number":42,"title":"Test","labels":[],"state":"OPEN"}]), 0}
    end)

    assert {:ok, [%{"number" => 42}]} = Lattice.GitHub.find_issue("Test")
  end

  test "required_labels returns expected set" do
    labels = Lattice.GitHub.required_labels()
    assert "proposed" in labels
    assert "approved" in labels
    assert "in-progress" in labels
    assert "blocked" in labels
    assert "done" in labels
  end
end
