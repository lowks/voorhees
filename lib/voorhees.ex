defmodule Voorhees do
  require IEx
  @moduledoc """
  A library for validating JSON responses
  """

  @doc """
  Returns true if the content matches the format of the expected keys matched in.

  ## Examples

  Validating simple objects

      iex> content = ~S[{ "foo": 1, "bar": "baz" }]
      iex> Voorhees.matches_schema?(content, [:foo, "bar"]) # Property names can be strings or atoms
      true

      # Extra keys
      iex> content = ~S[{ "foo": 1, "bar": "baz", "boo": 3 }]
      iex> Voorhees.matches_schema?(content, [:foo, "bar"])
      false

      # Missing keys
      iex> content = ~S[{ "foo": 1 }]
      iex> Voorhees.matches_schema?(content, [:foo, "bar"])
      false

  Validating lists of objects

      iex> content = ~S/[{ "foo": 1, "bar": "baz" },{ "foo": 2, "bar": "baz" }]/
      iex> Voorhees.matches_schema?(content, [:foo, "bar"])
      true


  Validating nested lists of objects

      iex> content = ~S/{ "foo": 1, "bar": [{ "baz": 2 }]}/
      iex> Voorhees.matches_schema?(content, [:foo, bar: [:baz]])
      true

  Validating that a property is a list of scalar values

      iex> content = ~S/{ "foo": 1, "bar": ["baz", 2]}/
      iex> Voorhees.matches_schema?(content, [:foo, bar: []])
      true

  """
  def matches_schema?(content, expected_keys) do
    expected_keys = _normalize_key_list(expected_keys)
    parsed_content =  Poison.decode!(content)

    _matches_schema?(parsed_content, expected_keys)
  end

  @doc """
  Returns true if the content matches the values from expected payload.
  Key/value pairs in the content that are not in the expected payload are ignored.
  Key/value pairs in the expected payload that are not in the content cause
  `matches_payload?` to return false

  ## Examples

  Expected payload can keys can be either strings or atoms

      iex> content = ~S[{ "foo": 1, "bar": "baz" }]
      iex> Voorhees.matches_payload?(content, %{ :foo => 1, "bar" => "baz" })
      true

  Extra key/value pairs in content are ignored

      iex> content = ~S[{ "foo": 1, "bar": "baz", "boo": 3 }]
      iex> Voorhees.matches_payload?(content, %{ :foo => 1, "bar" => "baz" })
      true

  Extra key/value pairs in expected payload cause the validation to fail

      iex> content = ~S[{ "foo": 1, "bar": "baz"}]
      iex> Voorhees.matches_payload?(content, %{ :foo => 1, "bar" => "baz", :boo => 3 })
      false

  Validates scalar lists

      iex> content = ~S/{ "foo": 1, "bar": ["baz"]}/
      iex> Voorhees.matches_payload?(content, %{ :foo => 1, "bar" => ["baz"] })
      true

      # Order is respected
      iex> content = ~S/{ "foo": 1, "bar": [1, "baz"]}/
      iex> Voorhees.matches_payload?(content, %{ :foo => 1, "bar" => ["baz", 1] })
      false
  """
  def matches_payload?(content, expected_payload) do
    expected_payload = _normalize_map_keys(expected_payload)
    parsed_content =  Poison.decode!(content)
    |> Enum.filter(fn
      {key, _value} ->
        expected_payload
        |> Map.keys
        |> Enum.member?(key)
    end)
    |> Enum.into(%{})

    Map.equal?(parsed_content, expected_payload)
  end

  defp _normalize_map_keys(map) do
    map
    |> Enum.map(fn
      {key, value} when is_binary(key) -> {key, value}
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
    end)
    |> Enum.into(%{})
  end

  defp _matches_schema?(content, expected_keys) when is_list(content) do
    content
    |> Enum.map(fn (element) -> _matches_schema?(element, expected_keys) end)
    |> Enum.all?
  end

  defp _matches_schema?(content, expected_keys) when is_map(content) do
    content_keys = content
    |> Map.keys
    |> _extract_subkeys(content)

    extra_keys = content_keys -- expected_keys
    missing_keys = expected_keys -- content_keys

    Enum.empty?(extra_keys) and Enum.empty?(missing_keys)
  end

  defp _normalize_key_list([]), do: []
  defp _normalize_key_list([key|rest]) when is_binary(key), do: [key|_normalize_key_list(rest)]
  defp _normalize_key_list([key|rest]) when is_atom(key), do: [Atom.to_string(key)|_normalize_key_list(rest)]
  defp _normalize_key_list([{key, subkeys}|rest]) when is_binary(key) and is_list(subkeys) do
    [{key, _normalize_key_list(subkeys)}|_normalize_key_list(rest)]
  end
  defp _normalize_key_list([{key, subkeys}|rest]) when is_atom(key) and is_list(subkeys) do
    [{Atom.to_string(key), _normalize_key_list(subkeys)}|_normalize_key_list(rest)]
  end

  defp _extract_subkeys([], _map), do: []
  defp _extract_subkeys([key|rest], map) do
    case map[key] do
      (value) when is_map(value) -> [{key, _extract_subkeys(Map.keys(value), value)}|_extract_subkeys(rest, map)]
      (value) when is_list(value) ->
        subkey_arrays = value
        |> Enum.map(fn
          (element) when is_map(element) -> _extract_subkeys(Map.keys(element), element)
          (_) -> []
        end)
        |> Enum.uniq

        if Enum.count(subkey_arrays) == 1, do: [subkey_arrays] = subkey_arrays

        [{key, subkey_arrays}|_extract_subkeys(rest, map)]
      (_) -> [key|_extract_subkeys(rest, map)]
    end
  end
end
