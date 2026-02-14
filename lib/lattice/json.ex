defmodule Lattice.Json do
  @moduledoc """
  Minimal JSON encoder/decoder. No external dependencies.
  Handles the subset of JSON needed by Lattice: maps, lists, strings,
  numbers, booleans, null.
  """

  # --- Encoder ---

  def encode!(value) do
    IO.iodata_to_binary(encode_value(value))
  end

  defp encode_value(nil), do: "null"
  defp encode_value(true), do: "true"
  defp encode_value(false), do: "false"
  defp encode_value(i) when is_integer(i), do: Integer.to_string(i)
  defp encode_value(f) when is_float(f), do: Float.to_string(f)
  defp encode_value(a) when is_atom(a), do: encode_value(Atom.to_string(a))

  defp encode_value(s) when is_binary(s) do
    [?", escape_string(s), ?"]
  end

  defp encode_value(l) when is_list(l) do
    inner = l |> Enum.map(&encode_value/1) |> Enum.intersperse(",")
    [?[, inner, ?]]
  end

  defp encode_value(m) when is_map(m) do
    pairs =
      m
      |> Enum.map(fn {k, v} ->
        [encode_value(to_string(k)), ?:, encode_value(v)]
      end)
      |> Enum.intersperse(",")

    [?{, pairs, ?}]
  end

  defp escape_string(s) do
    s
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
    |> String.replace("\t", "\\t")
  end

  # --- Decoder ---

  def decode!(str) do
    {value, _rest} = parse_value(String.trim(str))
    value
  end

  def decode(str) do
    {:ok, decode!(str)}
  rescue
    _ -> {:error, :invalid_json}
  end

  defp parse_value(<<"\"", rest::binary>>), do: parse_string(rest, [])
  defp parse_value(<<"true", rest::binary>>), do: {true, rest}
  defp parse_value(<<"false", rest::binary>>), do: {false, rest}
  defp parse_value(<<"null", rest::binary>>), do: {nil, rest}
  defp parse_value(<<"[", rest::binary>>), do: parse_array(skip_ws(rest), [])
  defp parse_value(<<"{", rest::binary>>), do: parse_object(skip_ws(rest), %{})

  defp parse_value(<<c, _::binary>> = str)
       when c in [?-, ?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9] do
    parse_number(str)
  end

  defp parse_value(<<ws, rest::binary>>) when ws in [?\s, ?\n, ?\r, ?\t] do
    parse_value(rest)
  end

  # String parsing
  defp parse_string(<<"\\\"", rest::binary>>, acc), do: parse_string(rest, [acc, "\""])
  defp parse_string(<<"\\\\", rest::binary>>, acc), do: parse_string(rest, [acc, "\\"])
  defp parse_string(<<"\\n", rest::binary>>, acc), do: parse_string(rest, [acc, "\n"])
  defp parse_string(<<"\\r", rest::binary>>, acc), do: parse_string(rest, [acc, "\r"])
  defp parse_string(<<"\\t", rest::binary>>, acc), do: parse_string(rest, [acc, "\t"])
  defp parse_string(<<"\\\/", rest::binary>>, acc), do: parse_string(rest, [acc, "/"])

  defp parse_string(<<"\\u", hex::binary-size(4), rest::binary>>, acc) do
    {code, _} = Integer.parse(hex, 16)
    parse_string(rest, [acc, <<code::utf8>>])
  end

  defp parse_string(<<"\"", rest::binary>>, acc), do: {IO.iodata_to_binary(acc), rest}
  defp parse_string(<<c, rest::binary>>, acc), do: parse_string(rest, [acc, <<c>>])

  # Number parsing
  defp parse_number(str) do
    {num_str, rest} = take_number_chars(str, [])
    num_str = IO.iodata_to_binary(num_str)

    if String.contains?(num_str, ".") or String.contains?(num_str, "e") or
         String.contains?(num_str, "E") do
      {String.to_float(num_str), rest}
    else
      {String.to_integer(num_str), rest}
    end
  end

  defp take_number_chars(<<c, rest::binary>>, acc)
       when c in [?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?., ?-, ?+, ?e, ?E] do
    take_number_chars(rest, [acc, <<c>>])
  end

  defp take_number_chars(rest, acc), do: {acc, rest}

  # Array parsing
  defp parse_array(<<"]", rest::binary>>, acc), do: {Enum.reverse(acc), rest}

  defp parse_array(str, acc) do
    {value, rest} = parse_value(skip_ws(str))
    rest = skip_ws(rest)

    case rest do
      <<",", rest::binary>> -> parse_array(skip_ws(rest), [value | acc])
      <<"]", rest::binary>> -> {Enum.reverse([value | acc]), rest}
    end
  end

  # Object parsing
  defp parse_object(<<"}", rest::binary>>, acc), do: {acc, rest}

  defp parse_object(str, acc) do
    {key, rest} = parse_value(skip_ws(str))
    <<":", rest::binary>> = skip_ws(rest)
    {value, rest} = parse_value(skip_ws(rest))
    acc = Map.put(acc, key, value)
    rest = skip_ws(rest)

    case rest do
      <<",", rest::binary>> -> parse_object(skip_ws(rest), acc)
      <<"}", rest::binary>> -> {acc, rest}
    end
  end

  defp skip_ws(<<c, rest::binary>>) when c in [?\s, ?\n, ?\r, ?\t], do: skip_ws(rest)
  defp skip_ws(str), do: str
end
