defmodule Repo.Migrations.AddComponentResources do
  @moduledoc """
  Add component model resources for the unified component system.

  Creates:
  - components: Component definitions
  - component_versions: Versioned component manifests
  - component_subscriptions: Asset subscriptions to components
  """
  use Ecto.Migration

  def up do
    # Components table
    create table(:components, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :current_version, :string
      add :roles, {:array, :atom}, null: false, default: []
      add :metadata, :map, default: "{}"
      add :inserted_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create unique_index(:components, [:name])

    # Component versions table
    create table(:component_versions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :component_id, references(:components, type: :uuid, on_delete: :delete_all),
          null: false

      add :version, :string, null: false
      add :manifest, :map, null: false, default: "{}"
      add :artefacts, :map, null: false, default: "{}"
      add :state, :string, null: false, default: "draft"
      add :inserted_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create unique_index(:component_versions, [:component_id, :version])
    create index(:component_versions, [:state])

    # Component subscriptions table
    create table(:component_subscriptions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :site_id, :uuid, null: false
      add :component_name, :string, null: false
      add :version_range, :string, null: false, default: ">= 0.0.0"
      add :pinned, :boolean, null: false, default: false
      add :pinned_version, :string
      add :resolved_version_id,
          references(:component_versions, type: :uuid, on_delete: :nilify_delete)

      add :inserted_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create unique_index(:component_subscriptions, [:site_id, :component_name])
    create index(:component_subscriptions, [:component_name])
    create index(:component_subscriptions, [:pinned])
  end

  def down do
    drop table(:component_subscriptions)
    drop table(:component_versions)
    drop table(:components)
  end
end
