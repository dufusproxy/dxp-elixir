defmodule Core.Metadata.MetadataSchema do
  @moduledoc """
  MetadataSchema defines typed metadata structures.
  Each schema defines what metadata fields are available for a specific type of asset.
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
    table("metadata_schemas")
    repo(Core.Repo)
  end

  json_api do
    type("metadata_schema")
    routes([
      :index,
      :show,
      :create,
      :update,
      :destroy
    ])

    default_fields([
      :name,
      :slug,
      :schema,
      :inserted_at,
      :updated_at
    ])
  end

  paper_trail do
    change_tracking_mode(:snapshot)
    store_action_name?(true)
  end

  archive do
    archive_related([Core.Metadata.MetadataValue])
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

    # Schema definition stored as JSON
    # Format: {"fields": [{"name": "title", "type": "string", "required": true}]}
    attribute :schema, :map do
      allow_nil?(false)
      default(%{})
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    # Metadata values using this schema
    has_many :metadata_values, Core.Metadata.MetadataValue do
      destination_attribute(:schema_id)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:name, :slug, :schema])
    end

    update :update do
      primary?(true)
      accept([:name, :slug, :schema])
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

  validations do
    # Slug should be unique per tenant
    # This will be enforced by database unique index
  end
end
