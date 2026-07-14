defmodule Core.Components.ComponentSubscription do
  @moduledoc """
  The ComponentSubscription resource - represents a subscription to a component.

  Assets (pages, layouts) subscribe to components by name and version range.
  Subscriptions can be overridden per-asset by pinning a specific version.

  ## Version Ranges

  Subscriptions use semver ranges to specify which versions they accept:
  - `"^1.2.3"` - Compatible with 1.x.x (>= 1.2.3 < 2.0.0)
  - `"~1.2.3"` - Patch updates only (>= 1.2.3 < 1.3.0)
  - `"1.2.3"` - Exact version
  - `">=1.2.3 <2.0.0"` - Range expression

  ## Pinning

  Assets can pin a specific version, overriding the subscription range.
  This is useful when:
  - A specific version is required for compatibility
  - Testing a new version before rolling out
  - Preventing automatic updates

  ## Example

      # Subscribe to article-page with compatible version range
      subscription =
        Core.Components.ComponentSubscription
        |> Ash.Changeset.for_create(:create, %{
          site_id: page_asset_id,
          component_name: "article-page",
          version_range: "^1.0.0"
        })
        |> Ash.create!()

      # Pin to specific version
      subscription
      |> Ash.Changeset.for_update(:pin_version, %{version: "1.2.3"})
      |> Ash.update!()

  """

  use Ash.Resource,
    domain: Core.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshPaperTrail.Resource,
      AshJsonApi.Resource
    ],
    authorizers: [
      Ash.Policy.Authorizer
    ]

  postgres do
    table("component_subscriptions")
    repo(Core.Repo)
  end

  json_api do
    type("component_subscription")
    routes([
      :index,
      :show,
      :create,
      :update,
      :destroy
    ])

    default_fields([
      :site_id,
      :component_name,
      :version_range,
      :pinned,
      :pinned_version,
      :inserted_at,
      :updated_at
    ])
  end

  paper_trail do
    change_tracking_mode(:snapshot)
    store_action_name?(true)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :site_id, :uuid do
      allow_nil?(false)
      public?(true)
      description("The asset ID of the site/page subscribing to the component")
    end

    attribute :component_name, :string do
      allow_nil?(false)
      public?(true)
      constraints(
        match: ~r/^[a-z0-9-]+$/,
        max_length: 255
      )
    end

    attribute :version_range, :string do
      allow_nil?(false)
      default(">= 0.0.0")
      public?(true)
      constraints(max_length: 100)
    end

    attribute :pinned, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
    end

    attribute :pinned_version, :string do
      allow_nil?(true)
      public?(true)
      constraints(
        match: ~r/^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?$/,
        max_length: 50
      )
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :component, Core.Components.Component do
      allow_nil?(true)
      source_attribute(:component_name)
    end

    belongs_to :resolved_version, Core.Components.ComponentVersion do
      allow_nil?(true)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :site_id,
        :component_name,
        :version_range,
        :pinned,
        :pinned_version
      ])

      change after_action(fn changeset, record ->
        # Resolve the component on creation
        case Core.Components.ComponentResolver.resolve_component(record.component_name) do
          {:ok, component} ->
            {:ok, record}

          {:error, _reason} ->
            {:error, "Component not found: #{record.component_name}"}
        end
      end)
    end

    read :read_by_site do
      argument :site_id, :uuid do
        allow_nil?(false)
      end

      filter(expr(site_id == ^arg(:site_id)))
    end

    read :read_by_component do
      argument :component_name, :string do
        allow_nil?(false)
      end

      filter(expr(component_name == ^arg(:component_name)))
    end

    update :pin_version do
      require_atomic?(false)

      argument :version, :string do
        allow_nil?(false)
        constraints(
          match: ~r/^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?$/,
          max_length: 50
        )
      end

      change(set_attribute(:pinned, true))
      change(set_attribute(:pinned_version, arg(:version)))
      change(after_action(&Core.Components.ComponentSubscription.Resolver.resolve_pin/2))
    end

    update :unpin_version do
      require_atomic?(false)

      change(set_attribute(:pinned, false))
      change(set_attribute(:pinned_version, nil))
      change(after_action(&Core.Components.ComponentSubscription.Resolver.resolve_unpin/2))
    end

    update :set_version_range do
      require_atomic?(false)

      argument :version_range, :string do
        allow_nil?(false)
        constraints(max_length: 100)
      end

      change(set_attribute(:version_range, arg(:version_range)))
      change(after_action(&Core.Components.ComponentSubscription.Resolver.resolve_range/2))
    end
  end

  validations do
    validate fn _changeset, _context ->
      # If pinned, pinned_version must be present
      # This is validated by attribute constraints
      :ok
    end
  end
end
