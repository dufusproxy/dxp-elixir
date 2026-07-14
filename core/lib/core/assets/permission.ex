defmodule Core.Assets.Permission do
  @moduledoc """
  Permission represents principal-level grants on assets.
  Each permission grants a specific level (:read, :write, :admin) to a principal on an asset.
  """
  use Ash.Resource,
    domain: Core.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshPaperTrail.Resource,
      AshArchival.Resource
    ]

  postgres do
    table("permissions")
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

    attribute :principal_id, :uuid do
      allow_nil?(false)
      public?(true)
      # Principal can be a user, group, or service account
    end

    attribute :principal_type, :atom do
      allow_nil?(false)
      default(:user)
      public?(true)
      # :user, :group, :service
    end

    attribute :level, :atom do
      allow_nil?(false)
      public?(true)
      # :read - can view the asset
      # :write - can edit the asset
      # :admin - full control including permissions
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    # Asset this permission applies to
    belongs_to :asset, Core.Assets.Asset do
      allow_nil?(false)
      source_attribute(:asset_id)
      destination_attribute(:id)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:asset_id, :principal_id, :principal_type, :level])

      # Invalidate permission cache on create
      change Core.Policies.Changes.InvalidatePermissionCache.invalidate_permission_cache()
    end

    update :update do
      primary?(true)
      accept([:level])

      # Allow non-atomic updates for cache invalidation
      require_atomic?(false)

      # Invalidate permission cache on update
      change Core.Policies.Changes.InvalidatePermissionCache.invalidate_permission_cache()
    end

    destroy :destroy do
      primary?(true)
      soft?(true)

      # Allow non-atomic destroys for cache invalidation
      require_atomic?(false)

      # Invalidate permission cache on destroy
      change Core.Policies.Changes.InvalidatePermissionCache.invalidate_permission_cache()
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:read, action: :read)
    define(:update, action: :update)
    define(:destroy, action: :destroy)
  end

  validations do
    # Ensure one principal has only one permission level per asset
    # This will be enforced by a unique index
  end
end
