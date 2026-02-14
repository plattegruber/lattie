defmodule Lattice.ConstitutionTest do
  use ExUnit.Case, async: true

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "lattice_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(tmp_dir, "docs"))

    File.write!(
      Path.join(tmp_dir, "docs/product-directive.md"),
      "# Product Directive\nLattice is a personal autonomous systems layer."
    )

    File.write!(
      Path.join(tmp_dir, "docs/technical-opinion.md"),
      "# Technical Opinion\nPrimary runtime: Elixir."
    )

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    %{tmp_dir: tmp_dir}
  end

  test "loads both constitutional documents", %{tmp_dir: tmp_dir} do
    assert {:ok, docs} = Lattice.Constitution.load(tmp_dir)
    assert Map.has_key?(docs, "docs/product-directive.md")
    assert Map.has_key?(docs, "docs/technical-opinion.md")
    assert docs["docs/product-directive.md"] =~ "autonomous systems layer"
  end

  test "returns error when documents are missing" do
    assert {:error, errors} =
             Lattice.Constitution.load("/nonexistent_dir_#{System.unique_integer()}")

    assert length(errors) == 2
  end

  test "load! raises on missing documents" do
    assert_raise RuntimeError, ~r/Failed to load constitution/, fn ->
      Lattice.Constitution.load!("/nonexistent_dir_#{System.unique_integer()}")
    end
  end

  test "files/0 returns expected file list" do
    files = Lattice.Constitution.files()
    assert "docs/product-directive.md" in files
    assert "docs/technical-opinion.md" in files
  end
end
