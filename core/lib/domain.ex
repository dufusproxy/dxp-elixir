defmodule Core.Domain do
  @moduledoc """
  The main Ash domain for the Core application.
  This domain aggregates all resources for the DXP platform.
  """
  use Ash.Domain,
    extensions: [AshPaperTrail.Domain]

  resources do
    resource(Core.Resources.Tenant)

    # Account resources
    resource(Core.Accounts.User)
    resource(Core.Accounts.Identity)
    resource(Core.Accounts.Token)

    # Asset model resources
    resource(Core.Assets.Asset)
    resource(Core.Assets.AssetLink)
    resource(Core.Assets.Permission)

    # Content resources
    resource(Core.Content.Page)

    # Component resources
    resource(Core.Components.Component)
    resource(Core.Components.ComponentVersion)
    resource(Core.Components.ComponentSubscription)

    # Metadata resources
    resource(Core.Metadata.MetadataSchema)
    resource(Core.Metadata.MetadataValue)

    # Workflow resources
    resource(Core.Workflows.Workflow)
    resource(Core.Workflows.WorkflowRun)
  end

  # Include all version resources from AshPaperTrail
  paper_trail do
    include_versions?(true)
  end
end
