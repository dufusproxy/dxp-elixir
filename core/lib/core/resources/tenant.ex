defmodule Core.Resources.Tenant do
  @moduledoc """
  Tenant resource for multi-tenancy support.
  This resource represents a tenant in the system.
  """
  use Ash.Resource,
    domain: Core.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshJsonApi.Resource
    ]

  postgres do
    table("tenants")
    repo(Core.Repo)
  end

  json_api do
    type("tenant")
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
      :inserted_at,
      :updated_at
    ])
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

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:name, :slug])
      change Core.DomainEvents.PublishDomainEvent.publish_domain_event()
    end

    update :update do
      primary?(true)
      accept([:name, :slug])
      require_atomic?(false)
      change Core.DomainEvents.PublishDomainEvent.publish_domain_event()
    end

    destroy :destroy do
      require_atomic?(false)
      change Core.DomainEvents.PublishDomainEvent.publish_domain_event()
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:read, action: :read)
    define(:update, action: :update)
    define(:destroy, action: :destroy)
  end
end
