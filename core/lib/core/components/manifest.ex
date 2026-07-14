defmodule Core.Components.Manifest do
  @moduledoc """
  Manifest parser and validator for component contracts.

  This module handles parsing and validation of manifest.yaml files
  that accompany component versions.

  ## Manifest Structure

  Required fields:
  - `name` - Component name (string, matches /^[a-z0-9-]+$/)
  - `version` - Semver version string (e.g., "1.0.0")
  - `roles` - Array of roles (:page, :layout, :component)
  - `artefacts` - Map containing render_server path

  Optional fields:
  - `expects_layout` - Layout specification
  - `props` - JSON Schema for props validation
  - `slots` - Named slots with type constraints
  - `events` - Named events with payload schemas
  - `modes` - Supported runtime modes (default: [:static])
  - `a11y` - Accessibility commitments

  ## Example

      iex> yaml = \"\"\"
      name: article-page
      version: 1.0.0
      roles:
        - page
      props:
        type: object
        properties:
          title:
            type: string
      artefacts:
        render_server: article-page.heex
      \"\"\"
      iex> Core.Components.Manifest.parse_yaml(yaml)
      {:ok, %{
        name: "article-page",
        version: "1.0.0",
        roles: [:page],
        props: %{...},
        artefacts: %{render_server: "article-page.heex"}
      }}

  """

  @type parsed_manifest :: %{
          optional(:name) => String.t(),
          optional(:version) => String.t(),
          optional(:roles) => [atom()],
          optional(:expects_layout) => %{optional(:matches_role) => atom(), optional(:default) => String.t()},
          optional(:props) => map(),
          optional(:slots) => map(),
          optional(:events) => map(),
          optional(:modes) => [atom()],
          optional(:a11y) => map(),
          optional(:artefacts) => %{
            optional(:render_server) => String.t(),
            optional(:render_client) => String.t(),
            optional(:styles) => String.t()
          }
        }

  @required_fields [:name, :version, :roles, :artefacts]
  @valid_roles [:page, :layout, :component]
  @valid_modes [:static, :live_view, :channels, :external]

  @doc """
  Parse YAML manifest string into a map.

  ## Examples

      iex> yaml = "name: test\\nversion: 1.0.0"
      iex> Core.Components.Manifest.parse_yaml(yaml)
      {:ok, %{name: "test", version: "1.0.0"}}

  """
  @spec parse_yaml(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_yaml(yaml) when is_binary(yaml) do
    try do
      # Parse YAML using yamerl
      parsed = :yamerl_constr.string(:binary.bin_to_list(yaml))

      # Extract the first document
      case parsed do
        [data | _] when is_list(data) ->
          # Convert yamerl internal format to simple map
          {:ok, normalize_map(data)}

        [] ->
          {:error, "No YAML document found"}

        _ ->
          {:error, "Invalid YAML structure"}
      end
    catch
      :throw, {:yamerl_exception, _} ->
        {:error, "Invalid YAML syntax"}

      :throw, {:yamerl_invalid_option, _} ->
        {:error, "Invalid YAML option"}

      {:yamerl_exception, _} ->
        {:error, "Invalid YAML syntax"}

      e ->
        {:error, "Failed to parse YAML: #{Exception.message(e)}"}
    end
  end

  @doc """
  Validate manifest structure against the contract.

  Returns :ok if valid, {:error, reason} if invalid.

  ## Examples

      iex> manifest = %{name: "test", version: "1.0.0", roles: [:page], artefacts: %{render_server: "test.heex"}}
      iex> Core.Components.Manifest.validate(manifest)
      :ok

      iex> manifest = %{name: "test", version: "1.0.0"}
      iex> Core.Components.Manifest.validate(manifest)
      {:error, "Missing required fields: [:artefacts, :roles]"}

  """
  @spec validate(map()) :: :ok | {:error, String.t()}
  def validate(manifest) when is_map(manifest) do
    with :ok <- validate_required_fields(manifest),
         :ok <- validate_name(manifest),
         :ok <- validate_version(manifest),
         :ok <- validate_roles(manifest),
         :ok <- validate_modes(manifest),
         :ok <- validate_artefacts(manifest),
         :ok <- validate_expects_layout(manifest),
         :ok <- validate_json_schema(manifest) do
      :ok
    end
  end

  @doc """
  Parse and validate YAML manifest in one step.

  ## Examples

      iex> yaml = "name: test\\nversion: 1.0.0\\nroles:\\n  - page\\nartefacts:\\n  render_server: test.heex"
      iex> Core.Components.Manifest.parse_and_validate(yaml)
      {:ok, %{name: "test", version: "1.0.0", roles: [:page], artefacts: %{render_server: "test.heex"}}}

  """
  @spec parse_and_validate(String.t()) :: {:ok, parsed_manifest()} | {:error, String.t()}
  def parse_and_validate(yaml) do
    with {:ok, manifest} <- parse_yaml(yaml),
         :ok <- validate(manifest) do
      {:ok, manifest}
    end
  end

  # Private functions

  defp normalize_map(list) when is_list(list) do
    # Check if this is a proplist (key-value tuples) or a plain list
    if Keyword.keyword?(list) or all_tuples?(list) do
      # Handle proplists format from yamerl - convert to map
      Enum.into(list, %{}, fn
        {k, v} when is_list(k) or is_binary(k) -> {normalize_key(k), normalize_value(v)}
        {k, v} -> {normalize_key(k), normalize_value(v)}
      end)
    else
      # Plain list - map over elements
      Enum.map(list, &normalize_value/1)
    end
  end

  defp normalize_map(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {normalize_key(k), normalize_value(v)} end)
  end
  defp normalize_map(other), do: other

  defp all_tuples?(list) when is_list(list) do
    Enum.all?(list, fn
      {_, _} -> true
      _ -> false
    end)
  end

  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key(key) when is_list(key), do: key |> List.to_string() |> normalize_key()  # Convert charlist to string, then to atom
  defp normalize_key(key) when is_binary(key) do
    # Convert known string keys to atoms for expected fields
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> key
    end
  end

  defp normalize_value(value) when is_list(value) do
    # Check if this is a proplist that looks like expects_layout
    if Keyword.keyword?(value) or all_tuples?(value) do
      # Convert proplist to map and normalize
      converted = Enum.into(value, %{}, fn {k, v} -> {normalize_key(k), normalize_value(v)} end)
      # Check if it has matches_role that needs conversion
      case Map.get(converted, :matches_role) do
        nil -> converted
        role when is_binary(role) or is_list(role) ->
          %{converted | matches_role: convert_to_safe_atom(role)}
        _ -> converted
      end
    else
      # Handle as regular list
      # Check if this is a charlist (single string value) or a list of values
      if List.ascii_printable?(value) and not Keyword.keyword?(value) and not all_tuples?(value) do
        # This is a charlist string, convert to binary
        List.to_string(value)
      else
        # Check if this is a list of strings (like roles: [page, layout])
        # or nested structure
        if Enum.all?(value, fn v -> is_binary(v) or is_list(v) end) do
          # List of strings/charlists - convert to atoms for roles, modes
          Enum.map(value, &convert_to_safe_atom/1)
        else
          normalize_map(value)
        end
      end
    end
  end
  defp normalize_value(value), do: normalize_map(value)

  # Convert string/charlist to atom safely - only for known valid values
  defp convert_to_safe_atom(str) when is_binary(str) do
    # Try existing atom first, fall back to regular conversion if safe
    try do
      String.to_existing_atom(str)
    rescue
      ArgumentError -> :erlang.binary_to_atom(str, :utf8)
    end
  end
  defp convert_to_safe_atom(charlist) when is_list(charlist) do
    charlist |> List.to_string() |> convert_to_safe_atom()
  end

  defp validate_required_fields(manifest) do
    missing = Enum.reject(@required_fields, &Map.has_key?(manifest, &1))

    case missing do
      [] -> :ok
      fields -> {:error, "Missing required fields: #{inspect(fields)}"}
    end
  end

  defp validate_name(%{name: name}) when is_binary(name) do
    case Regex.match?(~r/^[a-z0-9-]+$/, name) do
      true -> :ok
      false -> {:error, "Invalid name: must match /^[a-z0-9-]+$/"}
    end
  end

  defp validate_name(_), do: {:error, "Name must be a string"}

  defp validate_version(%{version: version}) when is_binary(version) do
    case Regex.match?(~r/^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?$/, version) do
      true -> :ok
      false -> {:error, "Invalid version: must be semver (e.g., 1.0.0)"}
    end
  end

  defp validate_version(_), do: {:error, "Version must be a string"}

  defp validate_roles(%{roles: roles}) when is_list(roles) do
    case Enum.all?(roles, &(&1 in @valid_roles)) do
      true -> :ok
      false -> {:error, "Invalid roles: must be one of #{inspect(@valid_roles)}"}
    end
  end

  defp validate_roles(_), do: {:error, "Roles must be a list"}

  defp validate_modes(%{modes: modes}) when is_list(modes) do
    case Enum.all?(modes, &(&1 in @valid_modes)) do
      true -> :ok
      false -> {:error, "Invalid modes: must be one of #{inspect(@valid_modes)}"}
    end
  end

  defp validate_modes(_), do: :ok

  defp validate_artefacts(%{artefacts: artefacts}) when is_map(artefacts) do
    case Map.get(artefacts, :render_server) do
      nil -> {:error, "artefacts must include render_server"}
      path when is_binary(path) -> :ok
      _ -> {:error, "artefacts.render_server must be a string"}
    end
  end

  defp validate_artefacts(_), do: {:error, "Artefacts must be a map"}

  defp validate_expects_layout(%{expects_layout: spec}) when is_map(spec) do
    with {:ok, _} when is_map(spec) <- validate_layout_spec(spec), do: :ok
  end

  defp validate_expects_layout(%{expects_layout: nil}), do: :ok
  defp validate_expects_layout(_), do: :ok

  defp validate_layout_spec(%{matches_role: role}) when role in @valid_roles, do: {:ok, role}
  defp validate_layout_spec(_), do: {:error, "expects_layout.matches_role must be one of #{inspect(@valid_roles)}"}

  defp validate_json_schema(%{props: props}) when is_map(props) do
    # Validate JSON Schema structure
    # This is a basic validation - full JSON Schema validation is complex
    # For now, we just check it's a map with type information
    case Map.get(props, :type) do
      nil -> {:error, "props schema must include a type"}
      _type -> :ok
    end
  end

  defp validate_json_schema(%{props: nil}), do: :ok
  defp validate_json_schema(_), do: :ok
end
