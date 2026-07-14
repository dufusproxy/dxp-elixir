defmodule Core.Components.ComponentResolver do
  @moduledoc """
  Component resolution utilities.

  This module provides functions for resolving components and their versions
  based on subscriptions and version ranges.
  """

  alias Core.Components.{Component, ComponentVersion, Semver}

  @doc """
  Resolve a component by name.

  Returns {:ok, component} or {:error, reason}.

  ## Examples

      iex> Core.Components.ComponentResolver.resolve_component("article-page")
      {:ok, %Component{name: "article-page", ...}}

  """
  def resolve_component(name) when is_binary(name) do
    case Ash.get(Component, %{name: name}) do
      {:ok, component} -> {:ok, component}
      {:error, _} -> {:error, :component_not_found}
    end
  end

  @doc """
  Resolve a specific version of a component.

  Returns {:ok, component_version} or {:error, reason}.

  ## Examples

      iex> Core.Components.ComponentResolver.resolve_version("article-page", "1.0.0")
      {:ok, %ComponentVersion{version: "1.0.0", ...}}

  """
  def resolve_version(component_name, version) when is_binary(component_name) and is_binary(version) do
    with {:ok, component} <- resolve_component(component_name),
         {:ok, version} <-
           Ash.read(
             ComponentVersion,
             filter: [component_id: component.id, version: version, state: :published]
           ) do
      case version do
        [single] -> {:ok, single}
        [] -> {:error, :version_not_found}
      end
    end
  end

  @doc """
  Resolve the effective version for a subscription.

  Returns {:ok, version_string} or {:error, reason}.

  ## Examples

      iex> Core.Components.ComponentResolver.resolve_subscription_version(subscription)
      {:ok, "1.2.3"}

  """
  def resolve_subscription_version(subscription) do
    cond do
      subscription.pinned && subscription.pinned_version ->
        # Use pinned version
        {:ok, subscription.pinned_version}

      subscription.version_range ->
        # Resolve latest version matching range
        resolve_latest_version(subscription.component_name, subscription.version_range)

      true ->
        {:error, :no_version_range}
    end
  end

  @doc """
  Resolve the latest version matching a version range.

  Returns {:ok, version_string} or {:error, reason}.

  ## Examples

      iex> Core.Components.ComponentResolver.resolve_latest_version("article-page", "^1.0.0")
      {:ok, "1.2.3"}

  """
  def resolve_latest_version(component_name, version_range) do
    with {:ok, component} <- resolve_component(component_name),
         {:ok, versions} <-
           Ash.read(
             ComponentVersion,
             filter: [component_id: component.id, state: :published],
             sort: [version: :desc]
           ) do
      version_strings = Enum.map(versions, & &1.version)

      case Semver.resolve(version_strings, version_range) do
        {:ok, version} -> {:ok, version}
        {:error, _} = err -> err
      end
    end
  end

  @doc """
  Update a subscription's resolved version based on its current configuration.

  Returns {:ok, updated_subscription} or {:error, reason}.

  ## Examples

      iex> Core.Components.ComponentResolver.update_resolved_version(subscription)
      {:ok, %ComponentSubscription{resolved_version_id: ...}}

  """
  def update_resolved_version(subscription) do
    with {:ok, version_string} <- resolve_subscription_version(subscription),
         {:ok, version_record} <-
           resolve_version(subscription.component_name, version_string) do
      subscription
      |> Ash.Changeset.for_update(:update, %{})
      |> Ash.Changeset.manage_relationship(
        :resolved_version,
        version_record,
        type: :append
      )
      |> Ash.update()
    end
  end
end
