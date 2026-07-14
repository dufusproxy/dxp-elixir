defmodule Core.Workflows.Workflow do
  @moduledoc """
  Workflow defines approval workflow structures.
  Each workflow defines the states and transitions for an asset type.
  """
  use Ash.Resource,
    domain: Core.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshPaperTrail.Resource,
      AshArchival.Resource
    ]

  postgres do
    table("workflows")
    repo(Core.Repo)
  end

  paper_trail do
    change_tracking_mode(:snapshot)
    store_action_name?(true)
  end

  archive do
    archive_related([Core.Workflows.WorkflowRun])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
    end

    # Which asset types this workflow applies to
    attribute :asset_types, {:array, :atom} do
      allow_nil?(false)
      default([])
      public?(true)
    end

    # Workflow definition as JSON
    # Format: {"states": [...], "transitions": [...]}
    attribute :definition, :map do
      allow_nil?(false)
      default(%{})
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    # Workflow runs using this workflow
    has_many :workflow_runs, Core.Workflows.WorkflowRun do
      destination_attribute(:workflow_id)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:name, :slug, :asset_types, :definition])
    end

    update :update do
      primary?(true)
      accept([:name, :slug, :asset_types, :definition])
    end

    destroy :destroy do
      primary?(true)
      soft?(true)
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:read, action: :read)
    define(:update, action: :update)
    define(:destroy, action: :destroy)
  end
end
