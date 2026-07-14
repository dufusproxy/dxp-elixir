defmodule Core.Assets.AssetTest do
  use Core.DataCase

  @moduletag :asset

  describe "Asset resource" do
    test "creates an asset with required attributes" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      assert asset.type == :page
      assert asset.role == :page
      assert asset.state == :draft
    end

    test "updates an asset" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      updated_asset =
        Ash.update!(
          Ash.Changeset.for_update(asset, :update, %{role: :layout})
        )

      assert updated_asset.role == :layout
    end

    test "archives an asset using soft delete" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      # Archive the asset using destroy action (AshArchival uses destroy for soft delete)
      Ash.destroy!(asset)

      # Asset should not appear in normal queries (soft deleted)
      assets = Ash.read!(Core.Assets.Asset)

      # Filter to ensure our specific asset is not present
      assert Enum.all?(assets, fn a -> a.id != asset.id end)
    end

    test "creates a paper trail version on create" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      # Version should be created
      versions =
        Ash.read!(Core.Assets.Asset.Version)
        |> Enum.filter(fn v -> v.version_source_id == asset.id end)

      assert length(versions) == 1
      version = List.first(versions)
      assert version.version_action_name == :create
    end

    test "creates a paper trail version on update" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      Ash.update!(Ash.Changeset.for_update(asset, :update, %{role: :layout}))

      # Two versions should exist (create and update)
      versions =
        Ash.read!(Core.Assets.Asset.Version)
        |> Enum.filter(fn v -> v.version_source_id == asset.id end)

      assert length(versions) == 2
    end

    test "creates a paper trail version on destroy" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      Ash.destroy!(Ash.Changeset.for_destroy(asset, :destroy))

      # Version should be created for destroy
      versions =
        Ash.read!(Core.Assets.Asset.Version)
        |> Enum.filter(fn v -> v.version_source_id == asset.id end)

      assert length(versions) == 2  # create and destroy
      destroy_version = Enum.find(versions, fn v -> v.version_action_name == :destroy end)
      assert destroy_version != nil
    end
  end

  describe "Asset state machine" do
    test "asset has initial draft state" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          })
        )

      # Verify the state attribute exists and has the initial value
      assert asset.state == :draft
    end
  end
end
