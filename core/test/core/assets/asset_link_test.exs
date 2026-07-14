defmodule Core.Assets.AssetLinkTest do
  use Core.DataCase

  @moduletag :asset_link

  describe "AssetLink resource" do
    test "creates a link between parent and child assets" do
      parent =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      child =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      link =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
            parent_id: parent.id,
            child_id: child.id,
            link_type: :primary
          })
        )

      assert link.parent_id == parent.id
      assert link.child_id == child.id
      assert link.link_type == :primary
    end

    test "queries links through parent relationship" do
      parent =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      child =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: parent.id,
          child_id: child.id,
          link_type: :secondary
        })
      )

      # Load parent with child_links
      parent_with_links =
        Ash.load!(parent, :child_links)

      assert length(parent_with_links.child_links) == 1
      link = List.first(parent_with_links.child_links)
      assert link.parent_id == parent.id
      assert link.child_id == child.id
    end

    test "archives a link using soft delete" do
      parent =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      child =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      link =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
            parent_id: parent.id,
            child_id: child.id,
            link_type: :secondary
          })
        )

      # Archive the link
      Ash.destroy!(Ash.Changeset.for_destroy(link, :destroy))

      # Link should not appear in normal queries
      links =
        Ash.read!(Core.Assets.AssetLink)

      # Filter to ensure our specific link is not present
      assert Enum.all?(links, fn l -> l.id != link.id end)
    end

    test "creates a paper trail version on create and update" do
      parent =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      child =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      link =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
            parent_id: parent.id,
            child_id: child.id,
            link_type: :secondary
          })
        )

      # Version should be created
      versions =
        Ash.read!(Core.Assets.AssetLink.Version)
        |> Enum.filter(fn v -> v.version_source_id == link.id end)

      assert length(versions) == 1

      # Update link type
      Ash.update!(
        Ash.Changeset.for_update(link, :update, %{link_type: :primary})
      )

      # Two versions should exist
      versions =
        Ash.read!(Core.Assets.AssetLink.Version)
        |> Enum.filter(fn v -> v.version_source_id == link.id end)

      assert length(versions) == 2
    end
  end
end
