defmodule Core.Implications.Verifiers.VerifyValidAssetTypes do
  @moduledoc """
  Verifies that all implied asset types are valid.

  This verifier checks that each `asset_type` in implications
  is a known asset type in the system.
  """
  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    module = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    dsl_state
    |> Spark.Dsl.Extension.get_entities([:implications])
    |> Enum.each(fn implication ->
      asset_type = implication.asset_type

      unless valid_asset_type?(asset_type) do
        raise Spark.Error.DslError,
          module: module,
          path: [:implications, :implies, asset_type],
          message: """
          Unknown asset type: #{inspect(asset_type)}

          Asset types must be one of the known types in the system.
          To add a new asset type, define it as a resource with a corresponding `type` attribute.

          Known asset types: #{inspect(valid_asset_types())}
          """
      end
    end)

    :ok
  end

  defp valid_asset_type?(asset_type) do
    asset_type in valid_asset_types()
  end

  defp valid_asset_types do
    # Known asset types in the system
    # This should be kept in sync with the actual asset types defined as resources
    [
      :url,
      :metadata_record,
      :redirect,
      :page,
      :layout,
      :component,
      :image,
      :file,
      :video,
      :audio,
      :form,
      :workflow,
      :user,
      :group,
      :site,
      :tenant
    ]
  end
end
