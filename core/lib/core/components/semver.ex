defmodule Core.Components.Semver do
  @moduledoc """
  Semantic versioning utilities for component version resolution.

  This module provides functions for parsing, comparing, and resolving
  semver versions and ranges.

  ## Version Format

  Versions follow semver: MAJOR.MINOR.PATCH[-PRERELEASE]

  Examples:
  - "1.0.0" - Standard version
  - "1.2.3-beta.1" - Pre-release version
  - "2.0.0-rc.1" - Release candidate

  ## Range Expressions

  Supported range operators:
  - `^1.2.3` - Compatible with version (~>= 1.2.3 < 2.0.0)
  - `~1.2.3` - Patch updates only (~>= 1.2.3 < 1.3.0)
  - `>=1.2.3` - Greater than or equal to
  - `<2.0.0` - Less than
  - `1.2.3` - Exact version
  - `*` - Any version

  Ranges can be combined with spaces (AND logic):
  - `">=1.2.3 <2.0.0"` - Between 1.2.3 (inclusive) and 2.0.0 (exclusive)

  ## Examples

      iex> Core.Components.Semver.compare("1.0.0", "1.0.1")
      :lt

      iex> Core.Components.Semver.satisfies?("1.2.3", "^1.0.0")
      true

      iex> Core.Components.Semver.resolve(["1.0.0", "1.2.3", "2.0.0"], "^1.0.0")
      {:ok, "1.2.3"}

  """

  @type version :: String.t()
  @type range :: String.t()
  @type comparison :: :lt | :eq | :gt

  @doc """
  Compare two semver versions.

  Returns :lt if v1 < v2, :eq if v1 == v2, :gt if v1 > v2.

  ## Examples

      iex> Core.Components.Semver.compare("1.0.0", "1.0.1")
      :lt

      iex> Core.Components.Semver.compare("1.2.3", "1.2.3")
      :eq

      iex> Core.Components.Semver.compare("2.0.0", "1.9.9")
      :gt

  """
  @spec compare(version(), version()) :: comparison()
  def compare(v1, v2) do
    {parts1, pre1} = parse_version(v1)
    {parts2, pre2} = parse_version(v2)

    case compare_parts(parts1, parts2) do
      :eq ->
        case {pre1, pre2} do
          {nil, nil} -> :eq
          {nil, _} -> :gt
          {_, nil} -> :lt
          _ -> compare_prerelease(pre1, pre2)
        end

      result ->
        result
    end
  end

  @doc """
  Check if a version satisfies a range expression.

  ## Examples

      iex> Core.Components.Semver.satisfies?("1.2.3", "^1.0.0")
      true

      iex> Core.Components.Semver.satisfies?("2.0.0", "^1.0.0")
      false

      iex> Core.Components.Semver.satisfies?("1.2.3", "~1.2.0")
      true

      iex> Core.Components.Semver.satisfies?("1.3.0", "~1.2.0")
      false

  """
  @spec satisfies?(version(), range()) :: boolean()
  def satisfies?(version, range) when is_binary(version) and is_binary(range) do
    case parse_range(range) do
      {:ok, constraints} -> check_constraints(version, constraints)
      {:error, _} -> false
    end
  end

  @doc """
  Resolve the highest version satisfying a range from a list of versions.

  Returns {:ok, version} or {:error, :no_matching_version}.

  ## Examples

      iex> Core.Components.Semver.resolve(["1.0.0", "1.2.3", "2.0.0"], "^1.0.0")
      {:ok, "1.2.3"}

      iex> Core.Components.Semver.resolve(["2.0.0", "3.0.0"], "^1.0.0")
      {:error, :no_matching_version}

  """
  @spec resolve([version()], range()) :: {:ok, version()} | {:error, :no_matching_version}
  def resolve(versions, range) when is_list(versions) and is_binary(range) do
    matching =
      versions
      |> Enum.filter(&satisfies?(&1, range))
      |> Enum.sort(&compare(&2, &1) == :lt)

    case matching do
      [highest | _] -> {:ok, highest}
      [] -> {:error, :no_matching_version}
    end
  end

  @doc """
  Parse a version string into its components.

  Returns {{major, minor, patch}, prerelease} or {:error, reason}.

  ## Examples

      iex> Core.Components.Semver.parse_version("1.2.3")
      {{1, 2, 3}, nil}

      iex> Core.Components.Semver.parse_version("1.2.3-beta.1")
      {{1, 2, 3}, "beta.1"}

  """
  @spec parse_version(version()) :: {{integer(), integer(), integer()}, String.t() | nil}
  def parse_version(version) when is_binary(version) do
    case Regex.run(~r/^(\d+)\.(\d+)\.(\d+)(?:-(.+))?$/, version) do
      [_, major, minor, patch, prerelease] ->
        {{String.to_integer(major), String.to_integer(minor), String.to_integer(patch)},
         prerelease}

      [_, major, minor, patch] ->
        {{String.to_integer(major), String.to_integer(minor), String.to_integer(patch)},
         nil}

      _ ->
        raise ArgumentError, "Invalid semver: #{version}"
    end
  end

  @doc """
  Parse a range expression into constraints.

  Returns {:ok, constraints} or {:error, reason}.

  Constraints are a list of tuples: {:exact, version}, {:gte, version},
  {:lt, version}, etc.

  ## Examples

      iex> {:ok, constraints} = Core.Components.Semver.parse_range("^1.2.3")
      iex> :gte in Keyword.keys(constraints)
      true

  """
  @spec parse_range(range()) :: {:ok, keyword()} | {:error, String.t()}
  def parse_range(range) when is_binary(range) do
    cond do
      range == "*" ->
        {:ok, []}

      String.starts_with?(range, "^") ->
        # Caret range: >=X.Y.Z < X+1.0.0
        version = String.slice(range, 1..-1//1)
        {{major, _minor, _patch}, _prerelease} = parse_version(version)
        next_major = major + 1
        upper = "#{next_major}.0.0"
        {:ok, [gte: version, lt: upper]}

      String.starts_with?(range, "~") ->
        # Tilde range: >=X.Y.Z < X.Y+1.0
        version = String.slice(range, 1..-1//1)
        {{major, minor, _patch}, _prerelease} = parse_version(version)
        upper = "#{major}.#{minor + 1}.0"
        {:ok, [gte: version, lt: upper]}

      String.contains?(range, " ") ->
        # Complex range: ">=1.2.3 <2.0.0" - check BEFORE single operator
        parts = String.split(range, " ", trim: true)
        parse_complex_range(parts, [])

      String.match?(range, ~r/^[><=!]/) ->
        # Operator range: >=1.2.3, >1.2.3, <2.0.0, <=2.0.0, =1.2.3
        parse_operator_range(range)

      Regex.match?(~r/^\d+\.\d+\.\d+$/, range) ->
        # Exact version
        {:ok, [exact: range]}

      true ->
        {:error, "Invalid range: #{range}"}
    end
  end

  # Private functions

  defp parse_complex_range([], acc), do: {:ok, Enum.reverse(acc)}

  defp parse_complex_range([part | rest], acc) do
    case parse_operator_range(part) do
      {:ok, [constraint]} -> parse_complex_range(rest, [constraint | acc])
      {:error, _} = err -> err
    end
  end

  defp parse_operator_range(range) do
    case Regex.run(~r/^(>=|<=|>|<|=)(\d+\.\d+\.\d+(?:-[a-zA-Z0-9.]+)?)$/, range) do
      [_, op, version] ->
        constraint =
          case op do
            ">=" -> :gte
            "<=" -> :lte
            ">" -> :gt
            "<" -> :lt
            "=" -> :exact
          end

        {:ok, [{constraint, version}]}

      _ ->
        {:error, "Invalid operator range: #{range}"}
    end
  end

  defp check_constraints(version, constraints) do
    Enum.all?(constraints, fn {op, constraint_version} ->
      check_constraint(version, op, constraint_version)
    end)
  end

  defp check_constraint(version, :exact, constraint_version) do
    compare(version, constraint_version) == :eq
  end

  defp check_constraint(version, :gte, constraint_version) do
    # Special handling: if constraint_version is prerelease, version must also be prerelease
    {_, constraint_pre} = parse_version(constraint_version)
    if constraint_pre != nil do
      {_, version_pre} = parse_version(version)
      if version_pre == nil do
        # Stable version doesn't satisfy prerelease constraint
        false
      else
        # Both prerelease, compare normally
        compare(version, constraint_version) in [:eq, :gt]
      end
    else
      # Normal constraint
      compare(version, constraint_version) in [:eq, :gt]
    end
  end

  defp check_constraint(version, :lte, constraint_version) do
    compare(version, constraint_version) in [:eq, :lt]
  end

  defp check_constraint(version, :gt, constraint_version) do
    compare(version, constraint_version) == :gt
  end

  defp check_constraint(version, :lt, constraint_version) do
    compare(version, constraint_version) == :lt
  end

  defp compare_parts({m1, mi1, p1}, {m2, mi2, p2}) do
    cond do
      m1 > m2 -> :gt
      m1 < m2 -> :lt
      mi1 > mi2 -> :gt
      mi1 < mi2 -> :lt
      p1 > p2 -> :gt
      p1 < p2 -> :lt
      true -> :eq
    end
  end

  defp compare_prerelease(pre1, pre2) do
    # Simple prerelease comparison - split by dots and compare
    parts1 = String.split(pre1, ".")
    parts2 = String.split(pre2, ".")

    compare_prerelease_parts(parts1, parts2)
  end

  defp compare_prerelease_parts([p1 | rest1], [p2 | rest2]) do
    # Try numeric comparison first
    num1 = parse_numeric(p1)
    num2 = parse_numeric(p2)

    cond do
      is_nil(num1) and is_nil(num2) ->
        # Both alpha, compare lexicographically
        cond do
          p1 > p2 -> :gt
          p1 < p2 -> :lt
          true -> compare_prerelease_parts(rest1, rest2)
        end

      is_nil(num1) and not is_nil(num2) ->
        # Alpha > numeric (numeric comes first)
        :gt

      not is_nil(num1) and is_nil(num2) ->
        # Numeric < alpha
        :lt

      true ->
        # Both numeric
        cond do
          num1 > num2 -> :gt
          num1 < num2 -> :lt
          true -> compare_prerelease_parts(rest1, rest2)
        end
    end
  end

  defp parse_numeric(str) do
    case Integer.parse(str) do
      {num, ""} -> num  # Entire string is a number
      _ -> nil
    end
  end

  defp compare_prerelease_parts([], []), do: :eq
  defp compare_prerelease_parts([], _), do: :lt
  defp compare_prerelease_parts(_, []), do: :gt
end
