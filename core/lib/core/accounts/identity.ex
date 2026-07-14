defmodule Core.Accounts.Identity do
  @moduledoc """
  Identity resource for OAuth/OIDC authentication.

  Stores the mapping between external identity providers (like Keycloak)
  and internal user accounts.
  """
  use Ash.Resource,
    domain: Core.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshJsonApi.Resource
    ]

  postgres do
    table("identities")
    repo(Core.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # The user this identity belongs to
    attribute :user_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    # The provider (e.g., :keycloak, :google, :github)
    attribute :provider, :atom do
      allow_nil?(false)
      public?(true)
    end

    # The user's ID in the provider's system
    attribute :uid, :string do
      allow_nil?(false)
      public?(true)
    end

    # Additional provider-specific data
    attribute :provider_data, :map do
      allow_nil?(true)
      default(%{})
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :user, Core.Accounts.User do
      allow_nil?(false)
      source_attribute(:user_id)
      destination_attribute(:id)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:user_id, :provider, :uid, :provider_data])
      change Core.DomainEvents.PublishDomainEvent.publish_domain_event()
    end

    update :update do
      primary?(true)
      accept([:provider_data])
      require_atomic?(false)
      change Core.DomainEvents.PublishDomainEvent.publish_domain_event()
    end

    destroy :destroy do
      primary?(true)
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

  validations do
    # Ensure unique (provider, uid) pair
    # Note: This will be enforced by a database unique index
  end
end
