defmodule Core.Assets.AssetLinkTest do
  use Core.DataCase

  @moduletag :asset_link
  @bypass_auth [authorize?: false]

  describe "AssetLink resource" do
    test "creates a link between parent and child assets" do
      parent =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      child =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      link =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
            parent_id: parent.id,
            child_id: child.id,
            link_type: :primary
          }),
          @bypass_auth
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
          }),
          @bypass_auth
        )

      child =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: parent.id,
          child_id: child.id,
          link_type: :secondary
        }),
        @bypass_auth
      )

      # Load parent with child_links
      parent_with_links =
        Ash.load!(parent, :child_links, @bypass_auth)

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
          }),
          @bypass_auth
        )

      child =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      link =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
            parent_id: parent.id,
            child_id: child.id,
            link_type: :secondary
          }),
          @bypass_auth
        )

      # Archive the link
      Ash.destroy!(Ash.Changeset.for_destroy(link, :destroy), @bypass_auth)

      # Link should not appear in normal queries
      links =
        Ash.read!(Core.Assets.AssetLink, @bypass_auth)

      # Filter to ensure our specific link is not present
      assert Enum.all?(links, fn l -> l.id != link.id end)
    end

    test "creates a paper trail version on create and update" do
      parent =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      child =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      link =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
            parent_id: parent.id,
            child_id: child.id,
            link_type: :secondary
          }),
          @bypass_auth
        )

      # Version should be created
      versions =
        Ash.read!(Core.Assets.AssetLink.Version, @bypass_auth)
        |> Enum.filter(fn v -> v.version_source_id == link.id end)

      assert length(versions) == 1

      # Update link type
      Ash.update!(
        Ash.Changeset.for_update(link, :update, %{link_type: :primary}),
        @bypass_auth
      )

      # Two versions should exist
      versions =
        Ash.read!(Core.Assets.AssetLink.Version, @bypass_auth)
        |> Enum.filter(fn v -> v.version_source_id == link.id end)

      assert length(versions) == 2
    end

    test "prevents creating a direct cycle (child -> parent)" do
      parent =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      child =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      # Create initial link: parent -> child
      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: parent.id,
          child_id: child.id,
          link_type: :primary
        }),
        @bypass_auth
      )

      # Attempt to create reverse link: child -> parent (would create a cycle)
      assert_raise(Ash.Error.Invalid, ~r/cycle/, fn ->
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
            parent_id: child.id,
            child_id: parent.id,
            link_type: :primary
          }),
          @bypass_auth
        )
      end)
    end

    test "prevents creating an indirect cycle (A -> B -> C -> A)" do
      asset_a =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      asset_b =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      asset_c =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      # Create chain: A -> B -> C
      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: asset_a.id,
          child_id: asset_b.id,
          link_type: :primary
        }),
        @bypass_auth
      )

      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: asset_b.id,
          child_id: asset_c.id,
          link_type: :primary
        }),
        @bypass_auth
      )

      # Attempt to create link: C -> A (would create a cycle)
      assert_raise(Ash.Error.Invalid, ~r/cycle/, fn ->
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
            parent_id: asset_c.id,
            child_id: asset_a.id,
            link_type: :primary
          }),
          @bypass_auth
        )
      end)
    end

    test "prevents creating a deep cycle (A -> B -> C -> D -> E -> A)" do
      assets =
        Enum.map(1..5, fn _i ->
          Ash.create!(
            Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
              type: :page,
              role: :page
            }),
            @bypass_auth
          )
        end)

      [a, b, c, d, e] = assets

      # Create chain: A -> B -> C -> D -> E
      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: a.id,
          child_id: b.id,
          link_type: :primary
        }),
        @bypass_auth
      )

      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: b.id,
          child_id: c.id,
          link_type: :primary
        }),
        @bypass_auth
      )

      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: c.id,
          child_id: d.id,
          link_type: :primary
        }),
        @bypass_auth
      )

      Ash.create!(
        Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
          parent_id: d.id,
          child_id: e.id,
          link_type: :primary
        }),
        @bypass_auth
      )

      # Attempt to create link: E -> A (would create a cycle)
      assert_raise(Ash.Error.Invalid, ~r/cycle/, fn ->
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
            parent_id: e.id,
            child_id: a.id,
            link_type: :primary
          }),
          @bypass_auth
        )
      end)
    end

    test "allows creating DAG with multiple parents" do
      parent1 =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      parent2 =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      child =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
            type: :page,
            role: :page
          }),
          @bypass_auth
        )

      # Create links: parent1 -> child and parent2 -> child (valid DAG)
      link1 =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
            parent_id: parent1.id,
            child_id: child.id,
            link_type: :primary
          }),
          @bypass_auth
        )

      link2 =
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
            parent_id: parent2.id,
            child_id: child.id,
            link_type: :secondary
          }),
          @bypass_auth
        )

      assert link1.parent_id == parent1.id
      assert link2.parent_id == parent2.id

      # Both links should exist
      all_links = Ash.read!(Core.Assets.AssetLink, @bypass_auth)
      assert length(all_links) == 2
    end

    test "allows creating linear chain (no cycles)" do
      assets =
        Enum.map(1..4, fn _i ->
          Ash.create!(
            Ash.Changeset.for_create(Core.Assets.Asset, :create, %{
              type: :page,
              role: :page
            }),
            @bypass_auth
          )
        end)

      [a, b, c, d] = assets

      # Create linear chain: A -> B -> C -> D
      for {parent, child} <- Enum.zip([a, b, c], [b, c, d]) do
        Ash.create!(
          Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
            parent_id: parent.id,
            child_id: child.id,
            link_type: :primary
          }),
          @bypass_auth
        )
      end

      # All links should be created successfully
      links = Ash.read!(Core.Assets.AssetLink, @bypass_auth)
      assert length(links) == 3
    end
  end
end
