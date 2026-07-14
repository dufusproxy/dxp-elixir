defmodule Core.Assets.AssetLink do
  @moduledoc """
  AssetLink represents edges in the asset graph DAG.
  Each link connects a parent asset to a child asset with a specific link type.
  """
  use Ash.Resource,
    domain: Core.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshPaperTrail.Resource,
      AshArchival.Resource
    ]

  postgres do
    table("asset_links")
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

    attribute :parent_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :child_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :link_type, :atom do
      allow_nil?(false)
      default(:secondary)
      public?(true)
      # :primary - one parent is primary (for components that have layouts)
      # :secondary - normal relationship
      # :notice - notification relationship
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    # Parent asset
    belongs_to :parent, Core.Assets.Asset do
      allow_nil?(false)
      source_attribute(:parent_id)
      destination_attribute(:id)
    end

    # Child asset
    belongs_to :child, Core.Assets.Asset do
      allow_nil?(false)
      source_attribute(:child_id)
      destination_attribute(:id)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:parent_id, :child_id, :link_type])

      # Prevent cycles in the DAG
      change fn changeset, _context -> Core.Assets.AssetLink.Policies.prevent_cycles(changeset) end
    end

    update :update do
      primary?(true)
      accept([:link_type])

      # Allow paper_trail to work atomically
      require_atomic?(false)
    end

    destroy :destroy do
      primary?(true)

      # Allow paper_trail to work atomically
      require_atomic?(false)

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
