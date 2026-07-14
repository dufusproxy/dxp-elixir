defmodule Core.Components.ManifestTest do
  @moduledoc """
  Tests for the Manifest parser and validator.
  """

  use Core.DataCase

  alias Core.Components.Manifest

  describe "parse_yaml/1" do
    test "parses valid YAML manifest" do
      yaml = """
      name: article-page
      version: 1.0.0
      roles:
        - page
      artefacts:
        render_server: article-page.heex
      """

      assert {:ok, manifest} = Manifest.parse_yaml(yaml)
      assert manifest.name == "article-page"
      assert manifest.version == "1.0.0"
      assert manifest.roles == [:page]
      assert manifest.artefacts.render_server == "article-page.heex"
    end

    test "parses manifest with optional fields" do
      yaml = """
      name: button
      version: 1.0.0
      roles:
        - component
      expects_layout:
        matches_role: layout
        default: default-layout
      props:
        type: object
        properties:
          label:
            type: string
      slots:
        default:
          accept:
            - component
      modes:
        - static
      a11y:
        role: button
      artefacts:
        render_server: button.heex
        styles: button.css
      """

      assert {:ok, manifest} = Manifest.parse_yaml(yaml)
      assert manifest.name == "button"
      assert manifest.roles == [:component]
      assert manifest.expects_layout.matches_role == :layout
      assert manifest.expects_layout.default == "default-layout"
      assert manifest.props.type == "object"
      assert manifest.slots.default.accept == [:component]
      assert manifest.modes == [:static]
      assert manifest.a11y.role == "button"
      assert manifest.artefacts.styles == "button.css"
    end

    test "returns error for invalid YAML" do
      yaml = """
      name: test
      invalid: [unclosed
      version: 1.0.0
      """

      assert {:error, _reason} = Manifest.parse_yaml(yaml)
    end

    test "handles empty YAML" do
      yaml = ""

      assert {:error, _reason} = Manifest.parse_yaml(yaml)
    end
  end

  describe "validate/1" do
    test "validates complete manifest with all required fields" do
      manifest = %{
        name: "article-page",
        version: "1.0.0",
        roles: [:page],
        artefacts: %{
          render_server: "article-page.heex"
        }
      }

      assert :ok = Manifest.validate(manifest)
    end

    test "validates manifest with pre-release version" do
      manifest = %{
        name: "button",
        version: "1.0.0-beta.1",
        roles: [:component],
        artefacts: %{
          render_server: "button.heex"
        }
      }

      assert :ok = Manifest.validate(manifest)
    end

    test "returns error for missing required fields" do
      manifest = %{
        name: "test"
      }

      assert {:error, error} = Manifest.validate(manifest)
      assert error =~ "Missing required fields"
      assert ":artefacts" in String.split(error, ["[", "]", ", "])
    end

    test "returns error for invalid name" do
      manifest = %{
        name: "Invalid Name!",
        version: "1.0.0",
        roles: [:page],
        artefacts: %{render_server: "test.heex"}
      }

      assert {:error, error} = Manifest.validate(manifest)
      assert error =~ "Invalid name"
    end

    test "returns error for invalid version format" do
      manifest = %{
        name: "test",
        version: "1.0",
        roles: [:page],
        artefacts: %{render_server: "test.heex"}
      }

      assert {:error, error} = Manifest.validate(manifest)
      assert error =~ "Invalid version"
    end

    test "returns error for invalid roles" do
      manifest = %{
        name: "test",
        version: "1.0.0",
        roles: [:invalid_role],
        artefacts: %{render_server: "test.heex"}
      }

      assert {:error, error} = Manifest.validate(manifest)
      assert error =~ "Invalid roles"
    end

    test "returns error for missing render_server in artefacts" do
      manifest = %{
        name: "test",
        version: "1.0.0",
        roles: [:page],
        artefacts: %{}
      }

      assert {:error, error} = Manifest.validate(manifest)
      assert error =~ "render_server"
    end

    test "returns error for invalid modes" do
      manifest = %{
        name: "test",
        version: "1.0.0",
        roles: [:page],
        modes: [:invalid_mode],
        artefacts: %{render_server: "test.heex"}
      }

      assert {:error, error} = Manifest.validate(manifest)
      assert error =~ "Invalid modes"
    end

    test "validates props schema with type" do
      manifest = %{
        name: "test",
        version: "1.0.0",
        roles: [:page],
        props: %{
          type: "object",
          properties: %{
            title: %{type: "string"}
          }
        },
        artefacts: %{render_server: "test.heex"}
      }

      assert :ok = Manifest.validate(manifest)
    end

    test "returns error for props schema without type" do
      manifest = %{
        name: "test",
        version: "1.0.0",
        roles: [:page],
        props: %{
          properties: %{title: %{type: "string"}}
        },
        artefacts: %{render_server: "test.heex"}
      }

      assert {:error, error} = Manifest.validate(manifest)
      assert error =~ "must include a type"
    end
  end

  describe "parse_and_validate/1" do
    test "parses and validates valid manifest" do
      yaml = """
      name: card
      version: 1.0.0
      roles:
        - component
      artefacts:
        render_server: card.heex
        styles: card.css
      """

      assert {:ok, manifest} = Manifest.parse_and_validate(yaml)
      assert manifest.name == "card"
      assert manifest.version == "1.0.0"
    end

    test "returns error for invalid manifest" do
      yaml = """
      name: invalid!
      version: not-a-version
      roles: []
      artefacts: {}
      """

      assert {:error, _reason} = Manifest.parse_and_validate(yaml)
    end

    test "returns parse error for malformed YAML" do
      yaml = """
      name: test
        broken
      indentation
      """

      assert {:error, _reason} = Manifest.parse_and_validate(yaml)
    end
  end

  describe "edge cases" do
    test "handles roles with multiple values" do
      manifest = %{
        name: "versatile",
        version: "1.0.0",
        roles: [:page, :layout],
        artefacts: %{render_server: "versatile.heex"}
      }

      assert :ok = Manifest.validate(manifest)
    end

    test "handles empty modes list" do
      manifest = %{
        name: "test",
        version: "1.0.0",
        roles: [:page],
        modes: [],
        artefacts: %{render_server: "test.heex"}
      }

      assert :ok = Manifest.validate(manifest)
    end

    test "validates expects_layout with valid role" do
      manifest = %{
        name: "test",
        version: "1.0.0",
        roles: [:page],
        expects_layout: %{matches_role: :layout, default: "default-layout"},
        artefacts: %{render_server: "test.heex"}
      }

      assert :ok = Manifest.validate(manifest)
    end

    test "returns error for expects_layout with invalid role" do
      manifest = %{
        name: "test",
        version: "1.0.0",
        roles: [:page],
        expects_layout: %{matches_role: :invalid},
        artefacts: %{render_server: "test.heex"}
      }

      assert {:error, _reason} = Manifest.validate(manifest)
    end

    test "handles nil expects_layout" do
      manifest = %{
        name: "test",
        version: "1.0.0",
        roles: [:page],
        expects_layout: nil,
        artefacts: %{render_server: "test.heex"}
      }

      assert :ok = Manifest.validate(manifest)
    end

    test "handles all valid modes" do
      valid_modes = [:static, :live_view, :channels, :external]

      Enum.each(valid_modes, fn mode ->
        manifest = %{
          name: "test",
          version: "1.0.0",
          roles: [:page],
          modes: [mode],
          artefacts: %{render_server: "test.heex"}
        }

        assert :ok = Manifest.validate(manifest)
      end)
    end
  end
end
