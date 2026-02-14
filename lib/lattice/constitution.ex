defmodule Lattice.Constitution do
  @moduledoc """
  Reads the governing documents from docs/.
  These files are immutable and form the constitutional basis of Lattice.
  """

  @constitution_files [
    "docs/product-directive.md",
    "docs/technical-opinion.md"
  ]

  def files, do: @constitution_files

  @doc """
  Loads both constitutional documents from the given root directory.
  Returns {:ok, %{"docs/product-directive.md" => content, ...}} or {:error, errors}.
  """
  def load(root_dir) do
    results =
      Enum.map(@constitution_files, fn file ->
        path = Path.join(root_dir, file)

        case File.read(path) do
          {:ok, content} -> {:ok, {file, content}}
          {:error, reason} -> {:error, {file, reason}}
        end
      end)

    errors = for {:error, e} <- results, do: e
    docs = for {:ok, d} <- results, do: d

    if errors != [] do
      {:error, errors}
    else
      {:ok, Map.new(docs)}
    end
  end

  @doc """
  Loads constitution or raises on failure.
  """
  def load!(root_dir) do
    case load(root_dir) do
      {:ok, docs} -> docs
      {:error, errors} -> raise "Failed to load constitution: #{inspect(errors)}"
    end
  end
end
