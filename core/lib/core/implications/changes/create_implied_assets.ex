defmodule Core.Implications.Changes.CreateImpliedAssets do
  @moduledoc """
  Ash change that creates implied assets after the source asset is created.

  This change runs in an `after_action` hook, which means:
  1. It only executes if the source asset was successfully created
  2. It has access to the created record with its ID
  3. If any implied asset creation fails, the entire transaction is rolled back

  ## Options

  * `:implications` - List of implication configurations from the DSL
  * `:resource` - The source resource module

  ## Implementation Notes

  For each implication:
  1. Calculate default attributes using the configured `default` strategy
  2. Create the implied asset with those attributes
  3. Create an AssetLink connecting source to implied asset
  4. Store the relationship in the result metadata
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    # Validate that options are correct
    with true <- Keyword.keyword?(opts),
         {:ok, implications} when is_list(implications) <- Keyword.fetch(opts, :implications),
         {:ok, resource} when is_atom(resource) <- Keyword.fetch(opts, :resource) do
      {:ok, opts}
    else
      _ -> {:error, "expected :implications and :resource options"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    # Only create implied assets on successful creation
    Ash.Changeset.after_action(changeset, fn changeset, result ->
      create_implied_assets(changeset, result, opts[:implications], opts[:resource])
    end)
  end

  defp create_implied_assets(changeset, source_asset, implications, source_resource) do
    tenant = Ash.Changeset.get_attribute(changeset, :tenant_id)

    # Create each implied asset
    results =
      Enum.reduce_while(implications, {:ok, source_asset, []}, fn implication,
                                                                      {:ok, asset,
                                                                       created_assets} ->
        case create_implied_asset(source_asset, implication, tenant, source_resource) do
          {:ok, implied_asset} ->
            {:cont, {:ok, asset, [implied_asset | created_assets]}}

          {:error, error} ->
            # If any implied asset creation fails, we rollback the whole transaction
            {:halt, {:error, error}}
        end
      end)

    case results do
      {:ok, asset, created_assets} ->
        # Add created assets to metadata for API response
        metadata = Map.get(asset, :__metadata__, %{})
        updated_metadata = Map.put(metadata, :implied_assets, Enum.reverse(created_assets))
        updated_asset = Map.put(asset, :__metadata__, updated_metadata)
        {:ok, updated_asset}

      {:error, error} ->
        # Add error to changeset to trigger rollback
        {:error, Ash.Changeset.add_error(changeset, error)}
    end
  end

  defp create_implied_asset(source_asset, implication, tenant, _source_resource) do
    # Skip if optional and not explicitly requested
    if implication.optional do
      # For now, we skip optional implications
      # In the future, this could be controlled via context/params
      {:ok, nil}
    else
      # Calculate default attributes for the implied asset
      default_attrs = calculate_default_attributes(source_asset, implication)

      # Merge in the type and tenant
      attrs =
        default_attrs
        |> Map.put(:type, implication.asset_type)
        |> Map.put(:tenant_id, tenant)

      # Create the implied asset
      case Ash.create(
             Ash.Changeset.for_create(Core.Assets.Asset, :create, attrs),
             tenant: tenant
           ) do
        {:ok, implied_asset} ->
          # Create AssetLink to connect source to implied
          case create_asset_link(source_asset, implied_asset, implication, tenant) do
            :ok ->
              {:ok, implied_asset}

            {:error, error} ->
              # Rollback implied asset creation
              Ash.destroy(implied_asset, action: :destroy, tenant: tenant)
              {:error, error}
          end

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp calculate_default_attributes(source_asset, implication) do
    case implication.default do
      :auto ->
        # Auto-calculate from source asset context
        auto_calculate_attributes(source_asset, implication.asset_type)

      {module, function} when is_atom(module) and is_atom(function) ->
        # Call custom function
        if function_exported?(module, function, 2) do
          apply(module, function, [source_asset, implication])
        else
          %{}
        end

      static_map when is_map(static_map) ->
        # Use static map
        static_map

      nil ->
        # Create with minimal required attributes
        %{}

      _ ->
        # Fallback for unexpected values
        %{}
    end
  end

  defp auto_calculate_attributes(source_asset, :url) do
    # Generate URL path from source asset
    # Try to get a slug or name attribute
    slug = Map.get(source_asset, :slug) || Map.get(source_asset, :name) || "untitled"
    %{path: "/#{slug}", role: nil}
  end

  defp auto_calculate_attributes(_source_asset, :metadata_record) do
    # Create empty metadata record
    %{role: nil}
  end

  defp auto_calculate_attributes(_source_asset, :redirect) do
    # Create redirect with minimal attributes
    %{role: nil}
  end

  defp auto_calculate_attributes(source_asset, _asset_type) do
    # Default fallback for unknown asset types
    %{
      role: nil,
      # Include source asset reference as a hint for further processing
      source_asset_id: source_asset.id
    }
  end

  defp create_asset_link(source, implied, implication, tenant) do
    # Determine link type based on implication
    link_type = determine_link_type(implication)

    Ash.create(
      Ash.Changeset.for_create(Core.Assets.AssetLink, :create, %{
        parent_id: source.id,
        child_id: implied.id,
        link_type: link_type
      }),
      tenant: tenant
    )
  rescue
    error -> {:error, error}
  else
    _ -> :ok
  end

  defp determine_link_type(_implication) do
    # Use :secondary as default for implied assets
    # This could be made configurable in the future
    :secondary
  end
end
