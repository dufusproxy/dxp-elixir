defmodule Core.Implications do
  @moduledoc """
  A Spark DSL extension for declaring asset implications.

  This extension adds an `implications` section to Ash resources that
  allows declaring which assets are automatically created when a source
  asset is created.

  ## Usage

      use Ash.Resource,
        domain: Core.Domain,
        data_layer: AshPostgres.DataLayer,
        extensions: [Core.Implications]

      implications do
        implies :url do
          default :auto
          surfaced_as :inline_field
          on_delete :convert_to_redirect
        end

        implies :metadata_record do
          default %{schema_id: "page_schema"}
          surfaced_as :advanced_panel
          on_delete :cascade
        end
      end

  ## Options

  * `:asset_type` - The type of asset that is implied (required, atom)
  * `:default` - How to create the implied asset:
    * `:auto` - Automatically compute from source asset context
    * `{module, function}` - Call module.function(source_asset, implication)
    * `map` - Static attributes to set
    * `nil` - Create with minimal required attributes
  * `:surfaced_as` - How the implied asset appears in the authoring UI:
    * `:inline_field` - Edit alongside source asset
    * `:advanced_panel` - Hidden in advanced settings panel
    * `:hidden` - Never shown in UI
  * `:on_delete` - Behavior when source asset is deleted:
    * `:cascade` - Delete the implied asset
    * `:convert_to_redirect` - Convert to redirect (for URL assets)
    * `:orphan` - Leave as-is (becomes independent)
    * `:block` - Prevent deletion if implied asset exists
  * `:optional` - If true, the implied asset is only created when explicitly requested

  ## Architecture

  The implications system uses a Spark DSL extension with:

  * **DSL Section**: `implications` block with `implies` entities
  * **Transformer**: Injects Ash changes for asset creation
  * **Verifiers**: Validate asset types and prevent circular implications
  * **Changes**: Runtime logic for creating implied assets and handling deletion

  ## Integration

  The extension integrates with Ash resources by:
  1. Storing implication metadata in the DSL state (compile-time)
  2. Injecting `after_action` changes to create implied assets (via transformer)
  3. Injecting `before_action` changes to handle cascade deletion (via transformer)
  4. Providing introspection via `Core.Implications.Info`
  """

  alias Core.Implications.Implication

  @implies_entity %Spark.Dsl.Entity{
    name: :implies,
    target: Implication,
    args: [:asset_type],
    identifier: {:auto, :unique_integer},
    schema: [
      asset_type: [
        type: :atom,
        required: true,
        doc: "The type of asset that is implied (e.g., :url, :metadata_record)."
      ],
      default: [
        type: {:or, [:atom, {:tuple, [:atom, :atom]}, :map, nil]},
        default: :auto,
        doc: """
        How to create the implied asset.
        * `:auto` - Automatically compute from source asset context
        * `{module, function}` - Call module.function(source_asset, implication)
        * `map` - Static attributes to set
        * `nil` - Create with minimal required attributes
        """
      ],
      surfaced_as: [
        type: {:in, [:inline_field, :advanced_panel, :hidden]},
        default: :advanced_panel,
        doc: """
        How the implied asset appears in the authoring UI.
        * `:inline_field` - Edit alongside source asset
        * `:advanced_panel` - Hidden in advanced settings panel
        * `:hidden` - Never shown in UI
        """
      ],
      on_delete: [
        type: {:in, [:cascade, :convert_to_redirect, :orphan, :block]},
        default: :cascade,
        doc: """
        Behavior when source asset is deleted.
        * `:cascade` - Delete the implied asset
        * `:convert_to_redirect` - Convert to redirect (for URL assets)
        * `:orphan` - Leave as-is (becomes independent)
        * `:block` - Prevent deletion if implied asset exists
        """
      ],
      optional: [
        type: :boolean,
        default: false,
        doc: "If true, the implied asset is only created when explicitly requested."
      ]
    ],
    transform: {Core.Implications.Transformers.NormalizeDefault, :transform, []}
  }

  @implications_section %Spark.Dsl.Section{
    name: :implications,
    describe: """
    Declare which assets this asset type automatically implies (creates).

    When an asset of this type is created, all implied assets are created
    automatically with sensible defaults. This eliminates the friction of
    manually creating dependent assets (e.g., creating a URL asset when
    creating a Page).
    """,
    examples: [
      """
      implications do
        implies :url do
          default :auto
          surfaced_as :inline_field
          on_delete :convert_to_redirect
        end

        implies :metadata_record do
          default %{schema_id: "page_schema"}
          surfaced_as :advanced_panel
          on_delete :cascade
        end
      end
      """
    ],
    entities: [
      @implies_entity
    ]
  }

  @sections [@implications_section]

  use Spark.Dsl.Extension,
    sections: @sections,
    transformers: [
      # Core.Implications.Transformers.BuildImplicationChange,
      Core.Implications.Transformers.NormalizeDefault
    ],
    verifiers: [
      Core.Implications.Verifiers.VerifyValidAssetTypes
    ]
end
