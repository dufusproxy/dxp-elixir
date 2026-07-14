defmodule Core.Content.Page do
  @moduledoc """
  Page asset type with implications.

  A Page represents a web page in the asset graph. When a Page is created,
  it automatically implies (creates) two related assets:
  * A URL asset for the page's public path
  * A metadata_record asset for SEO and other metadata

  ## Implications

  * `:url` - Created with inline field UI, converts to redirect on delete
  * `:metadata_record` - Created in advanced panel, cascades on delete

  ## Usage

      page =
        Core.Content.Page
        |> Ash.Changeset.for_create(:create, %{
          slug: "about-us",
          title: "About Us"
        })
        |> Ash.create!()

      # The page now has implied assets:
      # - A URL asset at path "/about-us"
      # - A metadata record with default schema

  """

  use Ash.Resource,
    domain: Core.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [
      AshPaperTrail.Resource,
      AshArchival.Resource,
      AshStateMachine,
      Core.Implications
    ]

  attributes do
    uuid_primary_key(:id)

    attribute :type, :atom do
      allow_nil?(false)
      default(:page)
    end

    attribute :role, :atom do
      allow_nil?(true)
      default(:page)
    end

    attribute :state, :atom do
      allow_nil?(false)
      default(:draft)
      public?(true)
      constraints(one_of: [:draft, :review, :live, :safe_edit, :archived])
    end

    attribute :slug, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :title, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :content, :string do
      allow_nil?(true)
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many :parent_links, Core.Assets.AssetLink do
      destination_attribute :child_id
      source_attribute :id
    end

    has_many :child_links, Core.Assets.AssetLink do
      destination_attribute :parent_id
      source_attribute :id
    end

    has_many :metadata_values, Core.Metadata.MetadataValue do
      destination_attribute :asset_id
      source_attribute :id
    end

    has_many :permissions, Core.Assets.Permission do
      destination_attribute :asset_id
      source_attribute :id
    end
  end

  calculations do
    # Placeholder for ancestors calculation - to be implemented in future milestone
    # For now, using a simple calculation that returns empty array
    calculate(:ancestors, {:array, :uuid}, expr([]))

    # Placeholder for descendants calculation - to be implemented in future milestone
    calculate(:descendants, {:array, :uuid}, expr([]))

    # Placeholder for paths calculation - to be implemented in future milestone
    # Using {:array, :map} as paths are lists of maps/structs
    calculate(:paths, {:array, :map}, expr([]))
  end

  state_machine do
    initial_states([:draft])

    transitions do
      transition :submit_for_review, from: :draft, to: :review
      transition :approve, from: :review, to: :live
      transition :reject, from: :review, to: :draft
      transition :start_safe_edit, from: :live, to: :safe_edit
      transition :commit_safe_edit, from: :safe_edit, to: :live
      transition :discard_safe_edit, from: :safe_edit, to: :live
      transition :archive, from: [:draft, :live], to: :archived
    end
  end

  paper_trail do
    change_tracking_mode(:snapshot)
    store_action_name?(true)
  end

  archive do
    archive_related([])
    exclude_destroy_actions([:archive])
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:slug, :title, :content]

      # Set initial state to draft
      change(fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :state, :draft)
      end)

      # Manually add the change to create implied assets
      change {Core.Implications.Changes.CreateImpliedAssets, implications: Core.Implications.Info.implications(__MODULE__), resource: __MODULE__}
    end

    update :update do
      primary? true
      accept [:slug, :title, :content]

      # Allow paper_trail to work atomically
      require_atomic?(false)
    end

    destroy :destroy do
      primary? true

      # Allow paper_trail to work atomically
      require_atomic?(false)

      # Use soft delete
      soft?(true)

      # Manually add the change to handle cascade deletion
      change {Core.Implications.Changes.HandleCascadeDelete, implications: Core.Implications.Info.implications(__MODULE__), resource: __MODULE__}
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

  implications do
    implies :url do
      default {Core.Content.Page, :default_url_attributes}
      surfaced_as :inline_field
      on_delete :convert_to_redirect
    end

    implies :metadata_record do
      default %{schema_id: "page_schema"}
      surfaced_as :advanced_panel
      on_delete :cascade
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:read, action: :read)
    define(:update, action: :update)
    define(:destroy, action: :destroy)
    define(:submit_for_review, action: :submit_for_review)
    define(:approve, action: :approve)
    define(:reject, action: :reject)
    define(:start_safe_edit, action: :start_safe_edit)
    define(:commit_safe_edit, action: :commit_safe_edit)
    define(:discard_safe_edit, action: :discard_safe_edit)
    define(:archive, action: :archive)
  end

  postgres do
    table("assets")
    repo(Core.Repo)
  end

  #
  # Helper functions for computing default attributes
  #

  @doc """
  Computes default attributes for a URL implied asset.

  This function is called by the implications system when creating
  the URL asset for a page.

  ## Examples

      iex> Core.Content.Page.default_url_attributes(%Core.Content.Page{slug: "about"}, nil)
      %{path: "/about", role: nil}

  """
  def default_url_attributes(page, _implication) do
    slug = Map.get(page, :slug) || "untitled"
    %{path: "/#{slug}", role: nil}
  end
end
