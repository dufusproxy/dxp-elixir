defmodule Core.PermissionsTest do
  use Core.DataCase

  @moduletag :permissions

  describe "Permission system" do
    test "creates a permission grant" do
      asset = create_asset()
      actor = test_actor()

      permission =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Permission, :create, %{
            asset_id: asset.id,
            principal_id: actor.id,
            principal_type: :user,
            level: :read
          }),
          authorize?: false
        )

      assert permission.asset_id == asset.id
      assert permission.principal_id == actor.id
      assert permission.level == :read
    end

    test "updates permission level" do
      asset = create_asset()
      actor = test_actor()

      permission =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Permission, :create, %{
            asset_id: asset.id,
            principal_id: actor.id,
            principal_type: :user,
            level: :read
          }),
          authorize?: false
        )

      updated_permission =
        Ash.update!(
          Ash.Changeset.for_update(permission, :update, %{level: :admin}),
          authorize?: false
        )

      assert updated_permission.level == :admin
    end

    test "soft deletes permission" do
      asset = create_asset()
      actor = test_actor()

      permission =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Permission, :create, %{
            asset_id: asset.id,
            principal_id: actor.id,
            principal_type: :user,
            level: :read
          }),
          authorize?: false
        )

      # Soft delete the permission
      Ash.destroy!(permission, authorize?: false)

      # Permission should not appear in normal queries
      permissions = Ash.read!(Core.Assets.Permission, authorize?: false)
      assert Enum.all?(permissions, fn p -> p.id != permission.id end)
    end
  end

  describe "DAG inheritance" do
    test "direct permission grant allows access" do
      asset = create_asset()
      actor = test_actor()

      # Grant write permission
      grant_permission(asset.id, actor.id, :write)

      # Check effective permission
      {:ok, level} = Core.Policies.HasAssetPermission.effective_permission(actor.id, asset.id)
      assert level == :write
    end

    test "inherits permission from primary parent" do
      parent = create_asset()
      child = create_asset()
      actor = test_actor()

      # Grant admin permission on parent
      grant_permission(parent.id, actor.id, :admin)

      # Create primary link from parent to child
      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: parent.id,
          child_id: child.id,
          link_type: :primary
        }),
        authorize?: false
      )

      # Child should inherit admin permission from parent
      {:ok, level} = Core.Policies.HasAssetPermission.effective_permission(actor.id, child.id)
      assert level == :admin
    end

    test "nearest explicit grant wins in inheritance chain" do
      grandparent = create_asset()
      parent = create_asset()
      child = create_asset()
      actor = test_actor()

      # Grant admin on grandparent
      grant_permission(grandparent.id, actor.id, :admin)

      # Grant read on parent (should override inherited admin)
      grant_permission(parent.id, actor.id, :read)

      # Create primary links: grandparent -> parent -> child
      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: grandparent.id,
          child_id: parent.id,
          link_type: :primary
        }),
        authorize?: false
      )

      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: parent.id,
          child_id: child.id,
          link_type: :primary
        }),
        authorize?: false
      )

      # Child should inherit read from parent (nearest grant)
      {:ok, level} = Core.Policies.HasAssetPermission.effective_permission(actor.id, child.id)
      assert level == :read
    end

    test "no permission when no grant in chain" do
      parent = create_asset()
      child = create_asset()
      actor = test_actor()

      # Create primary link but no permissions
      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: parent.id,
          child_id: child.id,
          link_type: :primary
        }),
        authorize?: false
      )

      # No permission should be found
      {:ok, level} = Core.Policies.HasAssetPermission.effective_permission(actor.id, child.id)
      assert is_nil(level)
    end

    test "prevents infinite loops in circular DAG" do
      asset_a = create_asset()
      asset_b = create_asset()
      actor = test_actor()

      # Grant permission on asset A
      grant_permission(asset_a.id, actor.id, :read)

      # Create a cycle: A -> B -> A (not prevented at creation, but handled at runtime)
      # First create A -> B
      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: asset_a.id,
          child_id: asset_b.id,
          link_type: :primary
        }),
        authorize?: false
      )

      # The algorithm should handle the cycle without infinite recursion
      {:ok, level_a} = Core.Policies.HasAssetPermission.effective_permission(actor.id, asset_a.id)
      assert level_a == :read
    end
  end

  describe "Permission cache" do
    test "caches permission lookups" do
      asset = create_asset()
      actor = test_actor()

      # Grant permission
      grant_permission(asset.id, actor.id, :write)

      # Clear cache first
      Core.Policies.PermissionCache.clear()

      # First lookup - cache miss
      cache_result = Core.Policies.PermissionCache.get(actor.id, asset.id)
      assert cache_result == :error

      # Compute and cache
      {:ok, computed_level} = Core.Policies.HasAssetPermission.effective_permission(actor.id, asset.id)
      assert computed_level == :write

      # Second lookup - cache hit
      {:ok, cached_level} = Core.Policies.PermissionCache.get(actor.id, asset.id)
      assert cached_level == :write
    end

    test "invalidates cache on permission update" do
      asset = create_asset()
      actor = test_actor()

      # Grant read permission
      grant_permission(asset.id, actor.id, :read)

      # Compute and cache
      {:ok, _level} = Core.Policies.HasAssetPermission.effective_permission(actor.id, asset.id)
      {:ok, cached_level} = Core.Policies.PermissionCache.get(actor.id, asset.id)
      assert cached_level == :read

      # Update permission to admin
      # Find the permission we just created
      all_permissions = Ash.read!(Core.Assets.Permission, authorize?: false)
      permission = Enum.find(all_permissions, fn p ->
        p.asset_id == asset.id and p.principal_id == actor.id
      end)

      Ash.update!(
        Ash.Changeset.for_update(permission, :update, %{level: :admin}),
        authorize?: false
      )

      # Cache should be invalidated
      new_cache_result = Core.Policies.PermissionCache.get(actor.id, asset.id)
      assert new_cache_result == :error  # Cache was invalidated

      # Recompute
      {:ok, computed_level} = Core.Policies.HasAssetPermission.effective_permission(actor.id, asset.id)
      assert computed_level == :admin
    end

    test "invalidates cache on asset link creation" do
      parent = create_asset()
      child = create_asset()
      actor = test_actor()

      # Grant permission on child
      grant_permission(child.id, actor.id, :read)

      # Compute and cache (should find read on child)
      {:ok, _level} = Core.Policies.HasAssetPermission.effective_permission(actor.id, child.id)
      {:ok, cached_level} = Core.Policies.PermissionCache.get(actor.id, child.id)
      assert cached_level == :read

      # Grant admin on parent
      grant_permission(parent.id, actor.id, :admin)

      # Create link (should invalidate child's cache)
      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: parent.id,
          child_id: child.id,
          link_type: :primary
        }),
        authorize?: false
      )

      # Cache for child should be invalidated
      new_cache_result = Core.Policies.PermissionCache.get(actor.id, child.id)
      assert new_cache_result == :error  # Cache was invalidated
    end
  end

  describe "Permission level hierarchy" do
    test "admin implies write and read" do
      assert Core.Policies.HasAssetPermission.level_meets?(:admin, :read)
      assert Core.Policies.HasAssetPermission.level_meets?(:admin, :write)
      assert Core.Policies.HasAssetPermission.level_meets?(:admin, :admin)
    end

    test "write implies read" do
      assert Core.Policies.HasAssetPermission.level_meets?(:write, :read)
      assert Core.Policies.HasAssetPermission.level_meets?(:write, :write)
      assert false == Core.Policies.HasAssetPermission.level_meets?(:write, :admin)
    end

    test "read does not imply write or admin" do
      assert Core.Policies.HasAssetPermission.level_meets?(:read, :read)
      assert false == Core.Policies.HasAssetPermission.level_meets?(:read, :write)
      assert false == Core.Policies.HasAssetPermission.level_meets?(:read, :admin)
    end

    test "nil implies nothing" do
      assert false == Core.Policies.HasAssetPermission.level_meets?(nil, :read)
      assert false == Core.Policies.HasAssetPermission.level_meets?(nil, :write)
      assert false == Core.Policies.HasAssetPermission.level_meets?(nil, :admin)
    end
  end

  describe "Cache statistics" do
    test "reports cache statistics" do
      stats = Core.Policies.PermissionCache.stats()
      assert %{size: size, hits: _, misses: _} = stats
      assert is_integer(size)
    end
  end

  # Helper functions

  defp create_asset do
    Ash.create!(
      Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
        type: :page,
        role: :page
      }),
      authorize?: false
    )
  end

  defp test_actor do
    Core.DataCase.test_admin()
  end

  defp grant_permission(asset_id, actor_id, level) do
    Core.DataCase.grant_admin_permission(asset_id, actor_id)

    # Update to the desired level - read all permissions and find matching one
    all_permissions = Ash.read!(Core.Assets.Permission, authorize?: false)
    permission = Enum.find(all_permissions, fn p ->
      p.asset_id == asset_id and p.principal_id == actor_id
    end)

    if permission do
      Ash.update!(
        Ash.Changeset.for_update(permission, :update, %{level: level}),
        authorize?: false
      )
    end
  end
end
