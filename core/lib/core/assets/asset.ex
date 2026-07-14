defmodule Core.Assets.Asset do
  @moduledoc """
  The Asset resource - the core of the asset graph.
  All assets (pages, images, components, etc.) are represented by this resource.
  """
  use Ash.Resource,
    domain: Core.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshPaperTrail.Resource,
      AshArchival.Resource,
      AshStateMachine
    ],
    authorizers: [
      Ash.Policy.Authorizer
    ]

  postgres do
    table("assets")
    repo(Core.Repo)
  end

  paper_trail do
    # Use snapshot mode for atomic operations
    change_tracking_mode(:snapshot)

    # Store action name for better version tracking
    store_action_name?(true)
  end

  state_machine do
    # Initial state
    initial_states([:draft])

    # Transitions
    transitions do
      # Draft can be submitted for review or archived
      transition(:submit_for_review, from: :draft, to: :review)
      transition(:archive, from: :draft, to: :archived)

      # Review can be rejected (back to draft) or approved
      transition(:reject, from: :review, to: :draft)
      transition(:approve, from: :review, to: :live)

      # Live can be archived or start safe edit
      transition(:archive, from: :live, to: :archived)
      transition(:start_safe_edit, from: :live, to: :safe_edit)

      # Safe edit can be committed (back to live) or discarded (to live)
      transition(:commit_safe_edit, from: :safe_edit, to: :live)
      transition(:discard_safe_edit, from: :safe_edit, to: :live)
    end
  end

  archive do
    # Use archived state for soft-deleted resources
    archive_related([])

    # Exclude archive action from automatic archival
    # (we use explicit state transitions instead)
    exclude_destroy_actions([:archive])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :type, :atom do
      allow_nil?(false)
      public?(true)
    end

    attribute :role, :atom do
      allow_nil?(true)
      public?(true)
      # Role can be :page, :layout, :component, etc.
      # nil for assets that don't have roles (e.g., images, users)
    end

    attribute :state, :atom do
      allow_nil?(false)
      default(:draft)
      public?(true)
      constraints(one_of: [:draft, :review, :live, :safe_edit, :archived])
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    # Parent relationship (many-to-many through AssetLink)
    has_many :parent_links, Core.Assets.AssetLink do
      destination_attribute(:child_id)
    end

    # Child relationship (many-to-many through AssetLink)
    has_many :child_links, Core.Assets.AssetLink do
      destination_attribute(:parent_id)
    end

    # Metadata values
    has_many :metadata_values, Core.Metadata.MetadataValue do
      destination_attribute(:asset_id)
    end

    # Permissions
    has_many :permissions, Core.Assets.Permission do
      destination_attribute(:asset_id)
    end
  end

  actions do
    defaults([:read])

    # Primary create action
    create :create do
      primary?(true)
      accept([:type, :role])

      # Set initial state to draft
      change(fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :state, :draft)
      end)
    end

    # Primary update action
    update :update do
      primary?(true)
      accept([:type, :role])

      # Allow paper_trail to work atomically
      require_atomic?(false)

      # Only allow updates on draft or safe_edit assets
      # This will be enforced by policies in Milestone 4
    end

    # Primary destroy - uses soft delete via AshArchival
    destroy :destroy do
      primary?(true)

      # Allow paper_trail to work atomically
      require_atomic?(false)

      # Use soft delete
      soft?(true)
    end

    # State machine transitions
    update :submit_for_review do
      accept([])
      change transition_state(:review)
    end

    update :approve do
      accept([])
      change transition_state(:live)
    end

    update :reject do
      accept([])
      change transition_state(:draft)
    end

    update :start_safe_edit do
      accept([])
      change transition_state(:safe_edit)
    end

    update :commit_safe_edit do
      accept([])
      change transition_state(:live)
    end

    update :discard_safe_edit do
      accept([])
      change transition_state(:live)
    end

    update :archive do
      accept([])
      change transition_state(:archived)
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:read, action: :read)
    define(:update, action: :update)
    define(:destroy, action: :destroy)

    # State machine transitions
    define(:submit_for_review, action: :submit_for_review)
    define(:approve, action: :approve)
    define(:reject, action: :reject)
    define(:start_safe_edit, action: :start_safe_edit)
    define(:commit_safe_edit, action: :commit_safe_edit)
    define(:discard_safe_edit, action: :discard_safe_edit)
    define(:archive, action: :archive)
  end

  policies do
    # If no actor is present, deny all access
    policy always() do
      authorize_if actor_present()
    end

    # Read actions require :read permission
    policy action_type(:read) do
      authorize_if {Core.Policies.HasAssetPermission, level: :read}
    end

    # Create and update actions require :write permission
    policy action_type(:create) do
      authorize_if {Core.Policies.HasAssetPermission, level: :write}
    end

    policy action_type(:update) do
      authorize_if {Core.Policies.HasAssetPermission, level: :write}
    end

    # State transition actions require :write permission
    policy action(:submit_for_review) do
      authorize_if {Core.Policies.HasAssetPermission, level: :write}
    end

    policy action(:approve) do
      authorize_if {Core.Policies.HasAssetPermission, level: :write}
    end

    policy action(:reject) do
      authorize_if {Core.Policies.HasAssetPermission, level: :write}
    end

    policy action(:start_safe_edit) do
      authorize_if {Core.Policies.HasAssetPermission, level: :write}
    end

    policy action(:commit_safe_edit) do
      authorize_if {Core.Policies.HasAssetPermission, level: :write}
    end

    policy action(:discard_safe_edit) do
      authorize_if {Core.Policies.HasAssetPermission, level: :write}
    end

    policy action(:archive) do
      authorize_if {Core.Policies.HasAssetPermission, level: :write}
    end

    # Destroy action requires :admin permission
    policy action_type(:destroy) do
      authorize_if {Core.Policies.HasAssetPermission, level: :admin}
    end
  end
end
