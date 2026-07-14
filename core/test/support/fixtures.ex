defmodule Core.Fixtures do
  @moduledoc """
  Test fixtures for Core resources.
  """

  @doc """
  Insert a tenant fixture.
  """
  def insert(:tenant, attrs) do
    default_attrs = %{
      name: "Test Tenant",
      slug: "test-tenant"
    }

    final_attrs = Map.merge(default_attrs, Map.new(attrs))

    Ash.create!(
      Ash.Changeset.for_create(Core.Resources.Tenant, :create, final_attrs)
    )
  end

  @doc """
  Insert an asset fixture.
  """
  def insert(:asset, attrs) do
    tenant = Keyword.get(attrs, :tenant, insert(:tenant, []))

    default_attrs = %{
      type: :page,
      role: :page
    }

    final_attrs =
      default_attrs
      |> Map.merge(Map.new(attrs))
      |> Map.delete(:tenant)

    Ash.create!(
      Ash.Changeset.for_create(Core.Assets.Asset, :create, final_attrs)
      |> Ash.Changeset.set_context(%{actor: %{tenant_id: tenant.id}})
    )
  end

  def insert(_fixture_name, _attrs) do
    raise "Unknown fixture"
  end
end
