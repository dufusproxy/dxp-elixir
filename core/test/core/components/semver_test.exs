defmodule Core.Components.SemverTest do
  @moduledoc """
  Tests for the Semver version resolution utilities.
  """

  use Core.DataCase

  alias Core.Components.Semver

  describe "compare/2" do
    test "compares equal versions" do
      assert Semver.compare("1.0.0", "1.0.0") == :eq
    end

    test "compares versions by patch" do
      assert Semver.compare("1.0.0", "1.0.1") == :lt
      assert Semver.compare("1.0.1", "1.0.0") == :gt
    end

    test "compares versions by minor" do
      assert Semver.compare("1.0.0", "1.1.0") == :lt
      assert Semver.compare("1.1.0", "1.0.0") == :gt
    end

    test "compares versions by major" do
      assert Semver.compare("1.0.0", "2.0.0") == :lt
      assert Semver.compare("2.0.0", "1.0.0") == :gt
    end

    test "compares complex versions" do
      assert Semver.compare("1.2.3", "1.2.10") == :lt
      assert Semver.compare("2.0.0", "1.9.9") == :gt
      assert Semver.compare("10.0.0", "9.9.9") == :gt
    end

    test "compares pre-release versions" do
      assert Semver.compare("1.0.0", "1.0.0-beta") == :gt
      assert Semver.compare("1.0.0-beta", "1.0.0") == :lt
      assert Semver.compare("1.0.0-alpha", "1.0.0-beta") == :lt
      assert Semver.compare("1.0.0-beta.1", "1.0.0-beta.2") == :lt
    end

    test "compares versions with same base but different prerelease" do
      assert Semver.compare("1.0.0-alpha", "1.0.0-alpha.1") == :lt
      assert Semver.compare("1.0.0-beta", "1.0.0-alpha.1") == :gt
    end
  end

  describe "parse_version/1" do
    test "parses standard version" do
      assert {{1, 2, 3}, nil} = Semver.parse_version("1.2.3")
    end

    test "parses version with prerelease" do
      assert {{1, 2, 3}, "beta.1"} = Semver.parse_version("1.2.3-beta.1")
      assert {{2, 0, 0}, "rc.1"} = Semver.parse_version("2.0.0-rc.1")
    end

    test "raises on invalid version" do
      assert_raise ArgumentError, fn ->
        Semver.parse_version("invalid")
      end

      assert_raise ArgumentError, fn ->
        Semver.parse_version("1.0")
      end
    end
  end

  describe "parse_range/1" do
    test "parses caret range" do
      assert {:ok, constraints} = Semver.parse_range("^1.2.3")
      assert {:gte, "1.2.3"} in constraints
      assert {:lt, "2.0.0"} in constraints
    end

    test "parses tilde range" do
      assert {:ok, constraints} = Semver.parse_range("~1.2.3")
      assert {:gte, "1.2.3"} in constraints
      assert {:lt, "1.3.0"} in constraints
    end

    test "parses exact version" do
      assert {:ok, constraints} = Semver.parse_range("1.2.3")
      assert {:exact, "1.2.3"} in constraints
    end

    test "parses wildcard" do
      assert {:ok, []} = Semver.parse_range("*")
    end

    test "parses greater than or equal" do
      assert {:ok, constraints} = Semver.parse_range(">=1.2.3")
      assert {:gte, "1.2.3"} in constraints
    end

    test "parses less than" do
      assert {:ok, constraints} = Semver.parse_range("<2.0.0")
      assert {:lt, "2.0.0"} in constraints
    end

    test "parses complex range" do
      assert {:ok, constraints} = Semver.parse_range(">=1.2.3 <2.0.0")
      assert {:gte, "1.2.3"} in constraints
      assert {:lt, "2.0.0"} in constraints
    end

    test "parses greater than" do
      assert {:ok, constraints} = Semver.parse_range(">1.2.3")
      assert {:gt, "1.2.3"} in constraints
    end

    test "parses less than or equal" do
      assert {:ok, constraints} = Semver.parse_range("<=2.0.0")
      assert {:lte, "2.0.0"} in constraints
    end

    test "parses equals with explicit operator" do
      assert {:ok, constraints} = Semver.parse_range("=1.2.3")
      assert {:exact, "1.2.3"} in constraints
    end

    test "returns error for invalid range" do
      assert {:error, _} = Semver.parse_range("invalid")
    end
  end

  describe "satisfies?/2" do
    test "exact version match" do
      assert Semver.satisfies?("1.2.3", "1.2.3")
      refute Semver.satisfies?("1.2.4", "1.2.3")
    end

    test "caret range compatibility" do
      assert Semver.satisfies?("1.2.3", "^1.0.0")
      assert Semver.satisfies?("1.9.9", "^1.0.0")
      refute Semver.satisfies?("2.0.0", "^1.0.0")
    end

    test "tilde range patch updates" do
      assert Semver.satisfies?("1.2.3", "~1.2.0")
      assert Semver.satisfies?("1.2.9", "~1.2.0")
      refute Semver.satisfies?("1.3.0", "~1.2.0")
      refute Semver.satisfies?("2.0.0", "~1.2.0")
    end

    test "greater than or equal" do
      assert Semver.satisfies?("1.2.3", ">=1.2.3")
      assert Semver.satisfies?("2.0.0", ">=1.2.3")
      refute Semver.satisfies?("1.2.2", ">=1.2.3")
    end

    test "less than" do
      assert Semver.satisfies?("1.9.9", "<2.0.0")
      refute Semver.satisfies?("2.0.0", "<2.0.0")
      refute Semver.satisfies?("2.1.0", "<2.0.0")
    end

    test "complex range" do
      assert Semver.satisfies?("1.5.0", ">=1.2.3 <2.0.0")
      assert Semver.satisfies?("1.2.3", ">=1.2.3 <2.0.0")
      assert Semver.satisfies?("1.9.9", ">=1.2.3 <2.0.0")
      refute Semver.satisfies?("2.0.0", ">=1.2.3 <2.0.0")
      refute Semver.satisfies?("1.2.2", ">=1.2.3 <2.0.0")
    end

    test "wildcard" do
      assert Semver.satisfies?("1.0.0", "*")
      assert Semver.satisfies?("99.99.99", "*")
    end

    test "prerelease versions" do
      assert Semver.satisfies?("1.0.0-beta", "^1.0.0-alpha")
      refute Semver.satisfies?("1.0.0", "^1.0.0-alpha")
    end
  end

  describe "resolve/2" do
    test "resolves highest version in range" do
      versions = ["1.0.0", "1.2.3", "2.0.0"]
      assert {:ok, "1.2.3"} = Semver.resolve(versions, "^1.0.0")
    end

    test "resolves with exact match" do
      versions = ["1.0.0", "1.2.3", "2.0.0"]
      assert {:ok, "1.2.3"} = Semver.resolve(versions, "1.2.3")
    end

    test "resolves with tilde range" do
      versions = ["1.2.0", "1.2.3", "1.3.0", "2.0.0"]
      assert {:ok, "1.2.3"} = Semver.resolve(versions, "~1.2.0")
    end

    test "resolves with complex range" do
      versions = ["1.0.0", "1.2.3", "1.5.0", "2.0.0"]
      assert {:ok, "1.5.0"} = Semver.resolve(versions, ">=1.2.0 <2.0.0")
    end

    test "returns error when no version matches" do
      versions = ["2.0.0", "3.0.0"]
      assert {:error, :no_matching_version} = Semver.resolve(versions, "^1.0.0")
    end

    test "handles empty version list" do
      assert {:error, :no_matching_version} = Semver.resolve([], "^1.0.0")
    end

    test "returns highest matching version with prereleases" do
      versions = ["1.0.0", "1.0.0-beta", "1.0.0-alpha"]
      assert {:ok, "1.0.0"} = Semver.resolve(versions, "^1.0.0")
    end

    test "handles unsorted input" do
      versions = ["1.5.0", "1.0.0", "1.2.3", "1.9.0"]
      assert {:ok, "1.9.0"} = Semver.resolve(versions, "^1.0.0")
    end

    test "resolves with caret at major 0" do
      versions = ["0.1.0", "0.2.0", "0.3.0", "1.0.0"]
      assert {:ok, "0.3.0"} = Semver.resolve(versions, "^0.1.0")
      refute Semver.satisfies?("1.0.0", "^0.1.0")
    end

    test "resolves with multiple constraints" do
      versions = ["1.0.0", "1.2.3", "1.5.0", "2.0.0"]
      assert {:ok, "1.5.0"} = Semver.resolve(versions, ">=1.2.0 <1.6.0")
    end
  end

  describe "edge cases" do
    test "handles large version numbers" do
      assert Semver.compare("100.0.0", "99.999.999") == :gt
    end

    test "handles version 0.0.0" do
      assert {{0, 0, 0}, nil} = Semver.parse_version("0.0.0")
    end

    test "handles version with zero padding" do
      # Semver doesn't allow leading zeros, but our parser should handle standard format
      assert {{1, 2, 3}, nil} = Semver.parse_version("1.02.3")
    end

    test "handles multiple spaces in complex range" do
      versions = ["1.5.0", "1.6.0", "2.0.0"]
      assert {:ok, "1.5.0"} = Semver.resolve(versions, ">=1.2.0   <1.6.0")
    end

    test "compares versions with different prerelease formats" do
      assert Semver.compare("1.0.0-alpha", "1.0.0-beta") == :lt
      assert Semver.compare("1.0.0-beta", "1.0.0-rc") == :lt
      assert Semver.compare("1.0.0-rc.1", "1.0.0") == :lt
    end
  end
end
