defmodule Core.Workflows.WorkflowRun do
  @moduledoc """
  WorkflowRun tracks workflow execution for a specific asset.
  Each run represents the state transition history of an asset through a workflow.
  """
  use Ash.Resource,
    domain: Core.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshPaperTrail.Resource,
      AshArchival.Resource
    ]

  postgres do
    table("workflow_runs")
    repo(Core.Repo)
  end

  paper_trail do
    change_tracking_mode(:snapshot)
    store_action_name?(true)
  end

  archive do
    archive_related([])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :asset_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :workflow_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    # Current state of this workflow run
    attribute :current_state, :atom do
      allow_nil?(false)
      default(:draft)
      public?(true)
    end

    # Who initiated this workflow run
    attribute :initiated_by, :uuid do
      allow_nil?(true)
      public?(true)
    end

    # Workflow status
    attribute :status, :atom do
      allow_nil?(false)
      default(:in_progress)
      public?(true)
      # :in_progress, :completed, :cancelled
    end

    # Additional context stored as JSON
    attribute :context, :map do
      allow_nil?(false)
      default(%{})
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)

    attribute :completed_at, :utc_datetime do
      allow_nil?(true)
    end
  end

  relationships do
    # Asset this workflow run is for
    belongs_to :asset, Core.Assets.Asset do
      allow_nil?(false)
      source_attribute(:asset_id)
      destination_attribute(:id)
    end

    # Workflow definition being used
    belongs_to :workflow, Core.Workflows.Workflow do
      allow_nil?(false)
      source_attribute(:workflow_id)
      destination_attribute(:id)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:asset_id, :workflow_id, :current_state, :initiated_by, :context])
    end

    update :update do
      primary?(true)
      accept([:current_state, :status, :context])
      require_atomic?(false)

      # Set completed_at when status changes to completed
      change(fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :status) do
          :completed ->
            Ash.Changeset.change_attribute(changeset, :completed_at, DateTime.utc_now())

          _ ->
            changeset
        end
      end)
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
