defmodule Core.Metadata.MetadataValue do
  @moduledoc """
  MetadataValue stores instance values bound to schemas.
  Each asset can have metadata values following a specific schema.
  """
  use Ash.Resource,
    domain: Core.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshPaperTrail.Resource,
      AshArchival.Resource,
      AshJsonApi.Resource
    ]

  postgres do
    table("metadata_values")
    repo(Core.Repo)
  end

  json_api do
    type("metadata_value")
    routes([
      :index,
      :show,
      :create,
      :update,
      :destroy
    ])

    default_fields([
      :asset_id,
      :schema_id,
      :values,
      :inserted_at,
      :updated_at
    ])
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

    attribute :schema_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    # Values stored as JSON
    # Format: {"title": "My Page", "description": "..."}
    attribute :values, :map do
      allow_nil?(false)
      default(%{})
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    # Asset this metadata belongs to
    belongs_to :asset, Core.Assets.Asset do
      allow_nil?(false)
      source_attribute(:asset_id)
      destination_attribute(:id)
    end

    # Schema defining the metadata structure
    belongs_to :schema, Core.Metadata.MetadataSchema do
      allow_nil?(false)
      source_attribute(:schema_id)
      destination_attribute(:id)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:asset_id, :schema_id, :values])
    end

    update :update do
      primary?(true)
      accept([:values])
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
