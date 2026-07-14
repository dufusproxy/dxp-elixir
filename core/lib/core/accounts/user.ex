defmodule Core.Accounts.User do
  @moduledoc """
  User resource representing authenticated users in the system.

  Users can be granted permissions on assets and can authenticate via various strategies.
  """
  use Ash.Resource,
    domain: Core.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshJsonApi.Resource
    ],
    authorizers: [
      Ash.Policy.Authorizer
    ]

  postgres do
    table("users")
    repo(Core.Repo)
  end

  json_api do
    type("user")
    routes([
      :index,
      :show,
      :create,
      :update
    ])

    default_fields([
      :email,
      :name,
      :inserted_at,
      :updated_at
    ])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :email, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :name, :string do
      allow_nil?(true)
      public?(true)
    end

    # Hashed password (never exposed via API)
    attribute :hashed_password, :string do
      allow_nil?(true)
      sensitive?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:email, :name])
      argument :password, :string do
        allow_nil?(true)
        constraints(min_length: 8)
      end

      argument :password_confirmation, :string do
        allow_nil?(true)
      end

      # Validate password confirmation if provided
      validate fn changeset, _context ->
        password = Ash.Changeset.get_argument(changeset, :password)
        confirmation = Ash.Changeset.get_argument(changeset, :password_confirmation)

        case {password, confirmation} do
          {nil, _} -> :ok
          {_, nil} ->
            Ash.Changeset.add_error(changeset, :password_confirmation, "must be provided")

          {p, c} when p != c ->
            Ash.Changeset.add_error(changeset, :password_confirmation, "does not match password")

          _ ->
            :ok
        end
      end

      # Hash password if provided
      change fn changeset, _context ->
        password = Ash.Changeset.get_argument(changeset, :password)

        if password do
          changeset
          |> Ash.Changeset.change_attribute(:hashed_password, hash_password(password))
        else
          changeset
        end
      end

      # Publish domain event
      change Core.DomainEvents.PublishDomainEvent.publish_domain_event()
    end

    update :update do
      primary?(true)
      accept([:email, :name])
      require_atomic?(false)
      change Core.DomainEvents.PublishDomainEvent.publish_domain_event()
    end

    # Password change action
    update :change_password do
      argument :password, :string do
        allow_nil?(false)
        constraints(min_length: 8)
      end

      argument :current_password, :string do
        allow_nil?(false)
      end

      argument :password_confirmation, :string do
        allow_nil?(false)
      end

      # Validate current password
      validate fn changeset, _context ->
        current_password = Ash.Changeset.get_argument(changeset, :current_password)
        user = changeset.data

        if verify_password(current_password, user.hashed_password) do
          :ok
        else
          Ash.Changeset.add_error(changeset, :current_password, "is incorrect")
        end
      end

      # Validate password confirmation
      validate fn changeset, _context ->
        password = Ash.Changeset.get_argument(changeset, :password)
        confirmation = Ash.Changeset.get_argument(changeset, :password_confirmation)

        if password != confirmation do
          Ash.Changeset.add_error(changeset, :password_confirmation, "does not match password")
        else
          :ok
        end
      end

      # Hash and set new password
      change fn changeset, _context ->
        password = Ash.Changeset.get_argument(changeset, :password)
        Ash.Changeset.change_attribute(changeset, :hashed_password, hash_password(password))
      end

      require_atomic?(false)
      change Core.DomainEvents.PublishDomainEvent.publish_domain_event()
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:read, action: :read)
    define(:update, action: :update)
    define(:change_password, action: :change_password)
  end

  policies do
    # Users can always read their own record
    policy actor_attribute_equals(:id, :id) do
      authorize_if always()
    end

    # Admin actions require admin permission
    policy action_type(:create) do
      authorize_if always() # For now, allow anyone to create users (will be restricted by API)
    end

    policy action_type(:update) do
      authorize_if actor_attribute_equals(:id, :id)
    end
  end

  validations do
    # Email must be unique
    # Note: This will be enforced by a database unique index
  end

  # Simple password hashing - will be replaced with AshAuthentication later
  defp hash_password(password) do
    # For now, use a simple hash - this will be replaced with proper bcrypt
    :crypto.hash(:sha256, password <> System.get_env("PASSWORD_SALT", "default_salt"))
    |> Base.encode64()
  end

  defp verify_password(password, hashed) do
    hash_password(password) == hashed
  end
end
