defmodule Core.Components.Component do
  @moduledoc """
  The Component resource - represents a component in the unified component model.

  A Component is a reusable piece of UI that can be used across the platform.
  Components have versions (ComponentVersion) and can be subscribed to by assets
  (ComponentSubscription).

  ## Roles

  Components can fill one or more roles:
  - `:page` - Represents a complete page
  - `:layout` - Represents a layout wrapper
  - `:component` - Represents a reusable component

  A single component can fill multiple roles. For example, a component could
  be both a page and a layout.

  ## Example

      component =
        Core.Components.Component
        |> Ash.Changeset.for_create(:create, %{
          name: "article-page",
          current_version: "1.0.0",
          roles: [:page],
          metadata: %{
            description: "Standard article page component",
            author: "DXP Team"
          }
        })
        |> Ash.create!()

  """

  use Ash.Resource,
    domain: Core.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshPaperTrail.Resource,
      AshArchival.Resource,
      AshJsonApi.Resource
    ],
    authorizers: [
      Ash.Policy.Authorizer
    ]

  postgres do
    table("components")
    repo(Core.Repo)
  end

  json_api do
    type("component")
    routes([
      :index,
      :show,
      :create,
      :update,
      :destroy
    ])

    default_fields([
      :name,
      :current_version,
      :roles,
      :metadata,
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
    exclude_destroy_actions([:archive])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      constraints(
        match: ~r/^[a-z0-9-]+$/,
        max_length: 255
      )
    end

    attribute :current_version, :string do
      allow_nil?(true)
      public?(true)
      constraints(
        match: ~r/^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?$/,
        max_length: 50
      )
    end

    attribute :roles, {:array, :atom} do
      allow_nil?(false)
      default([])
      public?(true)
      constraints(
        items: [
          one_of: [:page, :layout, :component]
        ]
      )
    end

    attribute :metadata, :map do
      allow_nil?(true)
      default(%{})
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many :versions, Core.Components.ComponentVersion do
      destination_attribute :component_id
      source_attribute :id
    end
  end

  actions do
    defaults([:read, :update, :destroy])

    create :create do
      primary?(true)

      accept([
        :name,
        :current_version,
        :roles,
        :metadata
      ])
    end

    read :read_by_name do
      argument :name, :string do
        allow_nil?(false)
      end

      filter(expr(name == ^arg(:name)))
    end

    update :set_current_version do
      require_atomic?(false)

      argument :version, :string do
        allow_nil?(false)
        constraints(
          match: ~r/^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?$/,
          max_length: 50
        )
      end

      change(set_attribute(:current_version, arg(:version)))
    end
  end

  changes do
    change after_action(fn changeset, record ->
      # Publish domain event on component changes
      # This will be used for cache invalidation
      {:ok, record}
    end)
  end
end
