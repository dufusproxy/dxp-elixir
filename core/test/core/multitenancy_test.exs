defmodule Core.MultitenancyTest do
  use Core.DataCase

  @moduletag :multitenancy

  describe "Resources" do
    test "creates and queries assets" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      # Just verify we can create and query - don't rely on empty database
      assets = Ash.read!(Core.Assets.Asset)
      assert is_list(assets)
      assert length(assets) > 0
      # Verify our specific asset is in the list
      assert Enum.any?(assets, fn a -> a.id == asset.id end)
    end

    test "creates and queries asset links" do
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

      # Just verify we can create and query - don't rely on empty database
      links = Ash.read!(Core.Assets.AssetLink)
      assert is_list(links)
      assert length(links) > 0
      # Verify our specific link is in the list
      assert Enum.any?(links, fn l -> l.id == link.id end)
    end
  end
end
