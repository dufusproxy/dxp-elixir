defmodule Core.Assets.AssetTest do
  use Core.DataCase

  @moduletag :asset

  # For resource functionality tests, bypass authorization
  # Authorization tests are in a separate test file
  @bypass_auth [authorize?: false]

  describe "Asset resource" do
    test "creates an asset with required attributes" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
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
          }),
          @bypass_auth
        )

      updated_asset =
        Ash.update!(
          Ash.Changeset.for_update(asset, :update, %{role: :layout}),
          @bypass_auth
        )

      assert updated_asset.role == :layout
    end

    test "archives an asset using soft delete" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      # Archive the asset using destroy action (AshArchival uses destroy for soft delete)
      Ash.destroy!(asset, @bypass_auth)

      # Asset should not appear in normal queries (soft deleted)
      assets = Ash.read!(Core.Assets.Asset, @bypass_auth)

      # Filter to ensure our specific asset is not present
      assert Enum.all?(assets, fn a -> a.id != asset.id end)
    end

    test "creates a paper trail version on create" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      # Version should be created
      versions =
        Ash.read!(Core.Assets.Asset.Version, @bypass_auth)
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
          }),
          @bypass_auth
        )

      Ash.update!(Ash.Changeset.for_update(asset, :update, %{role: :layout}), @bypass_auth)

      # Two versions should exist (create and update)
      versions =
        Ash.read!(Core.Assets.Asset.Version, @bypass_auth)
        |> Enum.filter(fn v -> v.version_source_id == asset.id end)

      assert length(versions) == 2
    end

    test "creates a paper trail version on destroy" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      Ash.destroy!(Ash.Changeset.for_destroy(asset, :destroy), @bypass_auth)

      # Version should be created for destroy
      versions =
        Ash.read!(Core.Assets.Asset.Version, @bypass_auth)
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
          }),
          @bypass_auth
        )

      # Verify the state attribute exists and has the initial value
      assert asset.state == :draft
    end

    test "transitions from draft to review via submit_for_review" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      reviewed_asset =
        Ash.update!(
          Ash.Changeset.for_update(asset, :submit_for_review),
          @bypass_auth
        )

      assert reviewed_asset.state == :review
    end

    test "transitions from review to live via approve" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      reviewed_asset =
        Ash.update!(
          Ash.Changeset.for_update(asset, :submit_for_review),
          @bypass_auth
        )

      live_asset =
        Ash.update!(
          Ash.Changeset.for_update(reviewed_asset, :approve),
          @bypass_auth
        )

      assert live_asset.state == :live
    end

    test "transitions from review to draft via reject" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      reviewed_asset =
        Ash.update!(
          Ash.Changeset.for_update(asset, :submit_for_review),
          @bypass_auth
        )

      draft_asset =
        Ash.update!(
          Ash.Changeset.for_update(reviewed_asset, :reject),
          @bypass_auth
        )

      assert draft_asset.state == :draft
    end

    test "transitions from live to safe_edit via start_safe_edit" do
      asset = create_live_asset()

      safe_edit_asset =
        Ash.update!(
          Ash.Changeset.for_update(asset, :start_safe_edit),
          @bypass_auth
        )

      assert safe_edit_asset.state == :safe_edit
    end

    test "transitions from safe_edit to live via commit_safe_edit" do
      asset = create_live_asset()

      safe_edit_asset =
        Ash.update!(
          Ash.Changeset.for_update(asset, :start_safe_edit),
          @bypass_auth
        )

      live_asset =
        Ash.update!(
          Ash.Changeset.for_update(safe_edit_asset, :commit_safe_edit),
          @bypass_auth
        )

      assert live_asset.state == :live
    end

    test "transitions from safe_edit to live via discard_safe_edit" do
      asset = create_live_asset()

      safe_edit_asset =
        Ash.update!(
          Ash.Changeset.for_update(asset, :start_safe_edit),
          @bypass_auth
        )

      live_asset =
        Ash.update!(
          Ash.Changeset.for_update(safe_edit_asset, :discard_safe_edit),
          @bypass_auth
        )

      assert live_asset.state == :live
    end

    test "transitions from draft to archived via archive" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      archived_asset =
        Ash.update!(
          Ash.Changeset.for_update(asset, :archive),
          @bypass_auth
        )

      assert archived_asset.state == :archived
    end

    test "transitions from live to archived via archive" do
      asset = create_live_asset()

      archived_asset =
        Ash.update!(
          Ash.Changeset.for_update(asset, :archive),
          @bypass_auth
        )

      assert archived_asset.state == :archived
    end

    test "creates paper trail versions on state transitions" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      reviewed_asset =
        Ash.update!(
          Ash.Changeset.for_update(asset, :submit_for_review),
          @bypass_auth
        )

      live_asset =
        Ash.update!(
          Ash.Changeset.for_update(reviewed_asset, :approve),
          @bypass_auth
        )

      versions =
        Ash.read!(Core.Assets.Asset.Version, @bypass_auth)
        |> Enum.filter(fn v -> v.version_source_id == live_asset.id end)

      assert length(versions) == 3

      action_names = Enum.map(versions, fn v -> v.version_action_name end)
      assert :create in action_names
      assert :submit_for_review in action_names
      assert :approve in action_names
    end

    test "complete review workflow: draft -> review -> live" do
      asset =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      assert asset.state == :draft

      reviewed_asset =
        Ash.update!(
          Ash.Changeset.for_update(asset, :submit_for_review),
          @bypass_auth
        )

      assert reviewed_asset.state == :review

      live_asset =
        Ash.update!(
          Ash.Changeset.for_update(reviewed_asset, :approve),
          @bypass_auth
        )

      assert live_asset.state == :live
    end

    test "complete safe edit workflow: live -> safe_edit -> live" do
      asset = create_live_asset()
      assert asset.state == :live

      safe_edit_asset =
        Ash.update!(
          Ash.Changeset.for_update(asset, :start_safe_edit),
          @bypass_auth
        )

      assert safe_edit_asset.state == :safe_edit

      committed_asset =
        Ash.update!(
          Ash.Changeset.for_update(safe_edit_asset, :commit_safe_edit),
          @bypass_auth
        )

      assert committed_asset.state == :live
    end
  end

  # Helper function to create a live asset
  defp create_live_asset do
    asset =
      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
          type: :page,
          role: :page
        }),
        @bypass_auth
      )

    reviewed_asset =
      Ash.update!(
        Ash.Changeset.for_update(asset, :submit_for_review),
        @bypass_auth
      )

    Ash.update!(
      Ash.Changeset.for_update(reviewed_asset, :approve),
      @bypass_auth
    )
  end
end
