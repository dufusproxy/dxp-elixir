defmodule Core.ImplicationsTest do
  use Core.DataCase

  alias Core.Implications.Info

  describe "DSL integration" do
    test "adds implication metadata to resource" do
      implications = Info.implications(Core.Content.Page)

      assert length(implications) == 2

      url_implication =
        Enum.find(implications, fn imp -> imp.asset_type == :url end)

      assert url_implication != nil
      assert url_implication.surfaced_as == :inline_field
      assert url_implication.on_delete == :convert_to_redirect
      assert url_implication.default == {Core.Content.Page, :default_url_attributes}

      metadata_implication =
        Enum.find(implications, fn imp -> imp.asset_type == :metadata_record end)

      assert metadata_implication != nil
      assert metadata_implication.surfaced_as == :advanced_panel
      assert metadata_implication.on_delete == :cascade
      assert metadata_implication.default == %{schema_id: "page_schema"}
    end

    test "returns empty list for resources without implications" do
      implications = Info.implications(Core.Assets.Asset)
      assert implications == []
    end
  end

  describe "Info helpers" do
    setup do
      :ok
    end

    test "implication_for/2 returns specific implication" do
      url_implication = Info.implication_for(Core.Content.Page, :url)
      assert url_implication.asset_type == :url
      assert url_implication.surfaced_as == :inline_field
    end

    test "implication_for/2 returns nil for unknown asset type" do
      assert Info.implication_for(Core.Content.Page, :unknown) == nil
    end

    test "implied_asset_types/1 returns all implied types" do
      types = Info.implied_asset_types(Core.Content.Page)
      assert :url in types
      assert :metadata_record in types
      assert length(types) == 2
    end

    test "has_implications?/1 returns true for resources with implications" do
      assert Info.has_implications?(Core.Content.Page) == true
    end

    test "has_implications?/1 returns false for resources without implications" do
      assert Info.has_implications?(Core.Assets.Asset) == false
    end

    test "inline_implications/1 returns only inline field implications" do
      inline = Info.inline_implications(Core.Content.Page)
      assert length(inline) == 1
      assert hd(inline).asset_type == :url
      assert hd(inline).surfaced_as == :inline_field
    end

    test "advanced_implications/1 returns only advanced panel implications" do
      advanced = Info.advanced_implications(Core.Content.Page)
      assert length(advanced) == 1
      assert hd(advanced).asset_type == :metadata_record
      assert hd(advanced).surfaced_as == :advanced_panel
    end

    test "cascade_implications/1 returns only cascade implications" do
      cascade = Info.cascade_implications(Core.Content.Page)
      assert length(cascade) == 1
      assert hd(cascade).asset_type == :metadata_record
      assert hd(cascade).on_delete == :cascade
    end

    test "redirect_implications/1 returns only redirect implications" do
      redirect = Info.redirect_implications(Core.Content.Page)
      assert length(redirect) == 1
      assert hd(redirect).asset_type == :url
      assert hd(redirect).on_delete == :convert_to_redirect
    end

    test "blocking_implications/1 returns only blocking implications" do
      blocking = Info.blocking_implications(Core.Content.Page)
      assert blocking == []
    end
  end

  describe "Implication struct helpers" do
    alias Core.Implications.Implication

    test "auto_create?/1" do
      assert Implication.auto_create?(%Implication{optional: false}) == true
      assert Implication.auto_create?(%Implication{optional: true}) == false
    end

    test "cascade?/1" do
      assert Implication.cascade?(%Implication{on_delete: :cascade}) == true
      assert Implication.cascade?(%Implication{on_delete: :orphan}) == false
    end

    test "convert_to_redirect?/1" do
      assert Implication.convert_to_redirect?(%Implication{on_delete: :convert_to_redirect}) ==
               true

      assert Implication.convert_to_redirect?(%Implication{on_delete: :cascade}) == false
    end

    test "orphan?/1" do
      assert Implication.orphan?(%Implication{on_delete: :orphan}) == true
      assert Implication.orphan?(%Implication{on_delete: :cascade}) == false
    end

    test "block?/1" do
      assert Implication.block?(%Implication{on_delete: :block}) == true
      assert Implication.block?(%Implication{on_delete: :cascade}) == false
    end

    test "inline_field?/1" do
      assert Implication.inline_field?(%Implication{surfaced_as: :inline_field}) == true
      assert Implication.inline_field?(%Implication{surfaced_as: :advanced_panel}) == false
    end

    test "advanced_panel?/1" do
      assert Implication.advanced_panel?(%Implication{surfaced_as: :advanced_panel}) ==
               true

      assert Implication.advanced_panel?(%Implication{surfaced_as: :hidden}) == false
    end

    test "hidden?/1" do
      assert Implication.hidden?(%Implication{surfaced_as: :hidden}) == true
      assert Implication.hidden?(%Implication{surfaced_as: :inline_field}) == false
    end
  end

  describe "Core.Content.Page helper functions" do
    test "default_url_attributes/2 generates URL from slug" do
      page = %Core.Content.Page{slug: "test-page"}
      attrs = Core.Content.Page.default_url_attributes(page, nil)

      assert attrs.path == "/test-page"
      assert attrs.role == nil
    end

    test "default_url_attributes/2 handles missing slug" do
      page = %Core.Content.Page{}
      attrs = Core.Content.Page.default_url_attributes(page, nil)

      assert attrs.path == "/untitled"
      assert attrs.role == nil
    end
  end
end
