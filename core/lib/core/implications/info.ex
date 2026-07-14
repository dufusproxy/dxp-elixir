defmodule Core.Implications.Info do
  @moduledoc """
  Introspection helpers for Core.Implications.

  Provides functions to query implication metadata from resources
  at compile time or runtime.
  """

  @doc """
  Returns all implications defined for a resource.

  ## Examples

      iex> Core.Implications.Info.implications(Core.Content.Page)
      [%Core.Implications.Implication{asset_type: :url}, ...]

  """
  @spec implications(Ash.Resource.t()) :: [Core.Implications.Implication.t()]
  def implications(resource) do
    Spark.Dsl.Extension.get_entities(resource, [:implications])
  end

  @doc """
  Returns the implication configuration for a specific asset type.

  ## Examples

      iex> Core.Implications.Info.implication_for(Core.Content.Page, :url)
      %Core.Implications.Implication{asset_type: :url, ...}

      iex> Core.Implications.Info.implication_for(Core.Content.Page, :nonexistent)
      nil

  """
  @spec implication_for(Ash.Resource.t(), atom()) :: Core.Implications.Implication.t() | nil
  def implication_for(resource, asset_type) do
    resource
    |> implications()
    |> Enum.find(&(&1.asset_type == asset_type))
  end

  @doc """
  Returns all asset types implied by this resource.

  ## Examples

      iex> Core.Implications.Info.implied_asset_types(Core.Content.Page)
      [:url, :metadata_record]

  """
  @spec implied_asset_types(Ash.Resource.t()) :: [atom()]
  def implied_asset_types(resource) do
    resource
    |> implications()
    |> Enum.map(& &1.asset_type)
  end

  @doc """
  Returns true if the resource has any implications defined.

  ## Examples

      iex> Core.Implications.Info.has_implications?(Core.Content.Page)
      true

      iex> Core.Implications.Info.has_implications?(Core.Assets.Asset)
      false

  """
  @spec has_implications?(Ash.Resource.t()) :: boolean()
  def has_implications?(resource) do
    implications(resource) != []
  end

  @doc """
  Returns all implications that should be shown as inline fields.

  ## Examples

      iex> Core.Implications.Info.inline_implications(Core.Content.Page)
      [%Core.Implications.Implication{asset_type: :url, surfaced_as: :inline_field}]

  """
  @spec inline_implications(Ash.Resource.t()) :: [Core.Implications.Implication.t()]
  def inline_implications(resource) do
    resource
    |> implications()
    |> Enum.filter(&Core.Implications.Implication.inline_field?/1)
  end

  @doc """
  Returns all implications that should be shown in advanced panels.

  ## Examples

      iex> Core.Implications.Info.advanced_implications(Core.Content.Page)
      [%Core.Implications.Implication{asset_type: :metadata_record, surfaced_as: :advanced_panel}]

  """
  @spec advanced_implications(Ash.Resource.t()) :: [Core.Implications.Implication.t()]
  def advanced_implications(resource) do
    resource
    |> implications()
    |> Enum.filter(&Core.Implications.Implication.advanced_panel?/1)
  end

  @doc """
  Returns all implications with :cascade on_delete behavior.

  ## Examples

      iex> Core.Implications.Info.cascade_implications(Core.Content.Page)
      [%Core.Implications.Implication{asset_type: :metadata_record, on_delete: :cascade}]

  """
  @spec cascade_implications(Ash.Resource.t()) :: [Core.Implications.Implication.t()]
  def cascade_implications(resource) do
    resource
    |> implications()
    |> Enum.filter(&Core.Implications.Implication.cascade?/1)
  end

  @doc """
  Returns all implications with :convert_to_redirect on_delete behavior.

  ## Examples

      iex> Core.Implications.Info.redirect_implications(Core.Content.Page)
      [%Core.Implications.Implication{asset_type: :url, on_delete: :convert_to_redirect}]

  """
  @spec redirect_implications(Ash.Resource.t()) :: [Core.Implications.Implication.t()]
  def redirect_implications(resource) do
    resource
    |> implications()
    |> Enum.filter(&Core.Implications.Implication.convert_to_redirect?/1)
  end

  @doc """
  Returns all implications that should block deletion.

  ## Examples

      iex> Core.Implications.Info.blocking_implications(Core.Content.Page)
      []

  """
  @spec blocking_implications(Ash.Resource.t()) :: [Core.Implications.Implication.t()]
  def blocking_implications(resource) do
    resource
    |> implications()
    |> Enum.filter(&Core.Implications.Implication.block?/1)
  end
end
