defmodule Core.Components.CompositionValidator do
  @moduledoc """
  Role and composition validation for component rendering.

  This module validates:
  - Page/layout/component role constraints
  - Slot type constraints
  - Layout chain compatibility (expects_layout)

  ## Role Constraints

  - `:page` - Top-level page component, can reference layouts
  - `:layout` - Wrapper component, can have nested layouts and component slots
  - `:component` - Reusable component, goes into slots

  ## Slot Validation

  Slots define where child components can be placed. Each slot has:
  - `accept` - List of accepted roles or component names
  - `required` - Whether the slot must be filled

  ## Layout Chains

  Components can declare `expects_layout` to specify a wrapper layout.
  This is validated to prevent cyclic dependencies.

  ## Examples

      iex> Core.Components.CompositionValidator.validate_slot(component, child_component)
      :ok

      iex> Core.Components.CompositionValidator.validate_layout_chain(page, layout)
      :ok

      iex> Core.Components.CompositionValidator.detect_layout_cycle([comp1, comp2, comp3])
      {:error, :cycle_detected}

  """

  @valid_roles [:page, :layout, :component]
  @max_depth 10

  @doc """
  Validate that a component can fill a specific role.

  Returns :ok if valid, {:error, reason} if invalid.

  ## Examples

      iex> Core.Components.CompositionValidator.validate_role(component, :page)
      :ok

      iex> Core.Components.CompositionValidator.validate_role(component, :invalid)
      {:error, :invalid_role}

  """
  def validate_role(component, role) when is_atom(role) do
    if role in @valid_roles do
      if role in component.roles do
        :ok
      else
        {:error, {:role_not_supported, role, component.roles}}
      end
    else
      {:error, :invalid_role}
    end
  end

  @doc """
  Validate that a child component can be placed in a parent's slot.

  Returns :ok if valid, {:error, reason} if invalid.

  ## Examples

      iex> Core.Components.CompositionValidator.validate_slot(parent_manifest, child_component)
      :ok

      iex> Core.Components.CompositionValidator.validate_slot(parent_manifest, child_component, "header")
      :ok

  """
  def validate_slot(parent_manifest, child_component, slot_name \\ :default) do
    with :ok <- validate_slots_exist(parent_manifest),
         {:ok, slot_spec} <- get_slot_spec(parent_manifest, slot_name),
         :ok <- validate_slot_accept(slot_spec, child_component) do
      :ok
    end
  end

  @doc """
  Validate a layout chain starting from a component.

  Follows the expects_layout declarations to ensure:
  - Layout chain is valid (matching roles)
  - No cycles exist in the chain
  - Depth is within limits

  Returns {:ok, chain} or {:error, reason}.

  ## Examples

      iex> Core.Components.CompositionValidator.validate_layout_chain(page_component, [layout_component])
      {:ok, [page, layout]}

      iex> Core.Components.CompositionValidator.validate_layout_chain(page_component, [layout_component, page_component])
      {:error, :cycle_detected}

  """
  def validate_layout_chain(start_component, available_components \\ []) do
    validate_chain_recursive(start_component, available_components, [], 0)
  end

  @doc """
  Detect cycles in a component chain.

  Returns {:error, :cycle_detected} if a cycle is found, :ok otherwise.

  ## Examples

      iex> Core.Components.CompositionValidator.detect_layout_chain([comp1, comp2, comp1])
      {:error, :cycle_detected}

      iex> Core.Components.CompositionValidator.detect_layout_chain([comp1, comp2, comp3])
      :ok

  """
  def detect_layout_chain(chain) when is_list(chain) do
    chain_ids = Enum.map(chain, & &1.id)

    if length(chain_ids) != length(Enum.uniq(chain_ids)) do
      {:error, :cycle_detected}
    else
      :ok
    end
  end

  @doc """
  Validate expects_layout declaration for a component.

  Returns :ok if valid, {:error, reason} if invalid.

  ## Examples

      iex> Core.Components.CompositionValidator.validate_expects_layout(manifest, available_layouts)
      :ok

  """
  def validate_expects_layout(manifest, available_components) do
    case manifest do
      %{expects_layout: nil} ->
        :ok

      %{expects_layout: expects_layout} when is_map(expects_layout) ->
        case Map.get(expects_layout, :matches_role) do
          nil ->
            {:error, :missing_matches_role}

          role when role in @valid_roles ->
            # Check that at least one component with this role is available
            matching_components =
              Enum.filter(available_components, fn comp ->
                role in comp.roles
              end)

            if matching_components == [] do
              {:error, {:no_matching_layout, role}}
            else
              :ok
            end

          role ->
            {:error, {:invalid_role_in_expects_layout, role}}
        end

      _ ->
        {:error, :invalid_expects_layout}
    end
  end

  # Private functions

  defp validate_slots_exist(manifest) do
    case Map.get(manifest, :slots) do
      nil -> :ok
      slots when is_map(slots) -> :ok
      _ -> {:error, :invalid_slots}
    end
  end

  defp get_slot_spec(manifest, slot_name) do
    slots = Map.get(manifest, :slots, %{})

    case Map.get(slots, slot_name) do
      nil ->
        # If slot doesn't exist, check if it's the default slot (implicit)
        if slot_name == :default and map_size(slots) == 0 do
          # No slots defined, so default slot accepts anything
          {:ok, %{accept: :any, required: false}}
        else
          {:error, {:slot_not_found, slot_name}}
        end

      slot_spec when is_map(slot_spec) ->
        {:ok, slot_spec}

      _ ->
        {:error, {:invalid_slot_spec, slot_name}}
    end
  end

  defp validate_slot_accept(slot_spec, child_component) do
    accept = Map.get(slot_spec, :accept, :any)

    case accept do
      :any ->
        :ok

      accept_list when is_list(accept_list) ->
        # Check if child component's roles match accepted roles
        if Enum.any?(child_component.roles, &(&1 in accept_list)) do
          :ok
        else
          {:error, {:role_not_accepted, child_component.roles, accept_list}}
        end

      _ ->
        {:error, :invalid_accept}
    end
  end

  defp validate_chain_recursive(current_component, available_components, chain, depth) do
    cond do
      depth >= @max_depth ->
        {:error, :max_depth_exceeded}

      current_component.id in Enum.map(chain, & &1.id) ->
        {:error, :cycle_detected}

      true ->
        # Get current component's manifest
        case get_component_manifest(current_component) do
          {:ok, manifest} ->
            case Map.get(manifest, :expects_layout) do
              nil ->
                # No layout required, chain is valid
                {:ok, Enum.reverse([current_component | chain])}

              expects_layout ->
                # Find matching layout
                role = Map.get(expects_layout, :matches_role)

                matching_layouts =
                  Enum.filter(available_components, fn comp ->
                    comp.id != current_component.id and role in comp.roles
                  end)

                case matching_layouts do
                  [layout | _] ->
                    # Continue validation with the layout
                    validate_chain_recursive(
                      layout,
                      available_components,
                      [current_component | chain],
                      depth + 1
                    )

                  [] ->
                    default = Map.get(expects_layout, :default)

                    if default do
                      # Use default layout by name
                      case find_layout_by_name(available_components, default) do
                        {:ok, default_layout} ->
                          validate_chain_recursive(
                            default_layout,
                            available_components,
                            [current_component | chain],
                            depth + 1
                          )

                        {:error, _} ->
                          {:error, {:default_layout_not_found, default}}
                      end
                    else
                      {:error, {:no_matching_layout, role}}
                    end
                end
            end

          {:error, _} = err ->
            err
        end
    end
  end

  defp get_component_manifest(component) do
    case component.current_version do
      nil ->
        {:error, :no_current_version}

      version_string ->
        # For now, we'll return a basic manifest
        # In the full implementation, this would load from ComponentVersion
        {:ok, %{name: component.name, version: version_string, roles: component.roles}}
    end
  end

  defp find_layout_by_name(components, name) do
    case Enum.find(components, fn comp -> comp.name == name end) do
      nil -> {:error, :not_found}
      comp -> {:ok, comp}
    end
  end
end
