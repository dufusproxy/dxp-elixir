defmodule Core.Components.ComponentVersion do
  @moduledoc """
  The ComponentVersion resource - represents a specific version of a component.

  Each ComponentVersion contains:
  - The parsed manifest data (from manifest.yaml)
  - Artefact paths (pointing to object storage)
  - State (draft, published, or archived)

  ## Manifest Structure

  The manifest is stored as a map containing:
  - `name` - Component name
  - `version` - Semver version string
  - `roles` - Array of roles (:page, :layout, :component)
  - `expects_layout` - Optional layout specification
  - `props` - JSON Schema for props validation
  - `slots` - Named slots with type constraints
  - `events` - Named events with payload schemas
  - `modes` - Supported runtime modes
  - `a11y` - Accessibility commitments
  - `artefacts` - Paths to render_server, render_client, styles

  ## Artefacts

  Artefacts are stored as a map with keys:
  - `render_server` - Path to HEEx template (e.g., "article-page.heex")
  - `render_client` - Path to client-side JS (optional)
  - `styles` - Path to CSS file (optional)

  ## Example

      version =
        Core.Components.ComponentVersion
        |> Ash.Changeset.for_create(:create, %{
          component_id: component_id,
          version: "1.0.0",
          manifest: manifest_map,
          artefacts: %{
            render_server: "article-page.heex",
            styles: "article-page.css"
          },
          state: :published
        })
        |> Ash.create!()

  """

  use Ash.Resource,
    domain: Core.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshPaperTrail.Resource,
      AshStateMachine,
      AshJsonApi.Resource
    ],
    authorizers: [
      Ash.Policy.Authorizer
    ]

  postgres do
    table("component_versions")
    repo(Core.Repo)
  end

  json_api do
    type("component_version")
    routes([
      :index,
      :show,
      :create,
      :update,
      :destroy
    ])

    default_fields([
      :version,
      :state,
      :manifest,
      :artefacts,
      :inserted_at,
      :updated_at
    ])
  end

  paper_trail do
    change_tracking_mode(:snapshot)
    store_action_name?(true)
  end

  state_machine do
    initial_states([:draft])

    transitions do
      transition(:publish, from: :draft, to: :published)
      transition(:archive, from: [:draft, :published], to: :archived)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :version, :string do
      allow_nil?(false)
      public?(true)
      constraints(
        match: ~r/^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?$/,
        max_length: 50
      )
    end

    attribute :manifest, :map do
      allow_nil?(false)
      default(%{})
      public?(true)
    end

    attribute :artefacts, :map do
      allow_nil?(false)
      default(%{})
      public?(true)
    end

    attribute :state, :atom do
      allow_nil?(false)
      default(:draft)
      public?(true)
      constraints(one_of: [:draft, :published, :archived])
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :component, Core.Components.Component do
      allow_nil?(false)
    end

    has_many :subscriptions, Core.Components.ComponentSubscription do
      destination_attribute :resolved_version_id
      source_attribute :id
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :version,
        :manifest,
        :artefacts,
        :state
      ])

      argument :component_id, :uuid do
        allow_nil?(false)
      end

      change(set_attribute(:component_id, arg(:component_id)))
    end

    update :update do
      primary?(true)
      require_atomic?(false)
      accept([
        :version,
        :manifest,
        :artefacts,
        :state
      ])
    end

    read :read_by_component do
      argument :component_id, :uuid do
        allow_nil?(false)
      end

      filter(expr(component_id == ^arg(:component_id)))
    end

    read :read_published do
      filter(expr(state == :published))
    end

    update :publish do
      require_atomic?(false)

      change(after_action(fn changeset, record ->
        # Update component's current_version when publishing
        component = Ash.get!(Core.Components.Component, record.component_id)

        component
        |> Ash.Changeset.for_update(:set_current_version, %{version: record.version})
        |> Ash.update!()

        {:ok, record}
      end))
    end

    update :archive do
      require_atomic?(false)
      accept([
        :state
      ])
    end
  end

  validations do
    validate fn changeset, _context ->
      # Ensure manifest contains required fields
      case Ash.Changeset.get_attribute(changeset, :manifest) do
        nil ->
          {:error, "manifest is required"}

        manifest ->
          required_fields = [:name, :version, :roles]
          missing = Enum.reject(required_fields, &Map.has_key?(manifest, &1))

          case missing do
            [] -> :ok
            fields -> {:error, "manifest missing required fields: #{inspect(fields)}"}
          end
      end
    end

    validate fn changeset, _context ->
      # Ensure artefacts contains render_server
      case Ash.Changeset.get_attribute(changeset, :artefacts) do
        nil ->
          {:error, "artefacts is required"}

        artefacts ->
          case Map.get(artefacts, :render_server) do
            nil -> {:error, "artefacts must include render_server"}
            _ -> :ok
          end
      end
    end
  end
end
