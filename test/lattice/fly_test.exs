defmodule Lattice.FlyTest do
  use ExUnit.Case

  setup do
    old_enable = System.get_env("LATTICE_ENABLE_FLYCTL")

    on_exit(fn ->
      if old_enable do
        System.put_env("LATTICE_ENABLE_FLYCTL", old_enable)
      else
        System.delete_env("LATTICE_ENABLE_FLYCTL")
      end

      Application.delete_env(:lattice, :system_cmd)
    end)

    :ok
  end

  test "disabled by default" do
    System.delete_env("LATTICE_ENABLE_FLYCTL")
    refute Lattice.Fly.enabled?()
  end

  test "can be enabled via env var" do
    System.put_env("LATTICE_ENABLE_FLYCTL", "true")
    assert Lattice.Fly.enabled?()
  end

  test "run returns error when disabled" do
    System.delete_env("LATTICE_ENABLE_FLYCTL")
    assert {:error, :flyctl_disabled} = Lattice.Fly.run("status")
  end

  test "safe commands are classified correctly" do
    assert Lattice.Fly.safe?("status")
    assert Lattice.Fly.safe?("list")
    assert Lattice.Fly.safe?("info")
    assert Lattice.Fly.safe?("logs")
    refute Lattice.Fly.safe?("deploy")
  end

  test "controlled commands are classified correctly" do
    assert Lattice.Fly.controlled?("deploy")
    assert Lattice.Fly.controlled?("scale")
    assert Lattice.Fly.controlled?("secrets")
    assert Lattice.Fly.controlled?("machine")
    refute Lattice.Fly.controlled?("status")
  end

  test "unknown commands are not allowed" do
    refute Lattice.Fly.command_allowed?("rm")
    refute Lattice.Fly.command_allowed?("destroy")
    refute Lattice.Fly.command_allowed?("apps")
  end

  test "disallowed commands rejected even when enabled" do
    System.put_env("LATTICE_ENABLE_FLYCTL", "true")
    assert {:error, {:command_not_allowed, "rm"}} = Lattice.Fly.run("rm")
  end

  test "controlled commands require approval when enabled" do
    System.put_env("LATTICE_ENABLE_FLYCTL", "true")
    assert {:error, {:approval_required, "deploy"}} = Lattice.Fly.run("deploy")
  end

  test "controlled commands succeed with explicit approval" do
    System.put_env("LATTICE_ENABLE_FLYCTL", "true")
    tmp_dir = Path.join(System.tmp_dir!(), "fly_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    Application.put_env(:lattice, :system_cmd, fn "flyctl", ["deploy"], _opts ->
      {"Deployed!", 0}
    end)

    assert {:ok, "Deployed!"} = Lattice.Fly.run("deploy", [], approved: true, root_dir: tmp_dir)

    File.rm_rf!(tmp_dir)
  end

  test "safe commands execute without approval when enabled" do
    System.put_env("LATTICE_ENABLE_FLYCTL", "true")
    tmp_dir = Path.join(System.tmp_dir!(), "fly_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    Application.put_env(:lattice, :system_cmd, fn "flyctl", ["status"], _opts ->
      {"running", 0}
    end)

    assert {:ok, "running"} = Lattice.Fly.run("status", [], root_dir: tmp_dir)

    File.rm_rf!(tmp_dir)
  end
end
