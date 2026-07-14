defmodule Core.Policies.PermissionCache do
  @moduledoc """
  ETS-backed permission cache with multi-node cache invalidation via Phoenix PubSub.

  This cache stores resolved permission levels to keep authorization off the render hot path.
  The cache is invalidated when permissions or asset links are mutated.

  ## Cache Key

  `{actor_id, asset_id}` → permission level

  ## Invalidation

  Cache entries are invalidated on:
  - Permission mutations (create, update, destroy)
  - AssetLink mutations (affects inheritance chain)

  Invalidation is broadcast via Phoenix PubSub to keep cache coherent across nodes.

  ## Usage

      # Get cached permission
      {:ok, level} = Core.Policies.PermissionCache.get(actor_id, asset_id)

      # Put permission in cache
      :ok = Core.Policies.PermissionCache.put(actor_id, asset_id, :write)

      # Invalidate cache for an actor
      :ok = Core.Policies.PermissionCache.invalidate_actor(actor_id)

      # Invalidate cache for an asset
      :ok = Core.Policies.PermissionCache.invalidate_asset(asset_id)
  """

  use GenServer
  require Logger

  @table_name __MODULE__
  @pubsub_topic "permission_cache"

  # Client API

  @doc """
  Start the permission cache.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get a permission level from the cache.
  Returns {:ok, level} or :error on cache miss.
  """
  def get(actor_id, asset_id) do
    case :ets.lookup(@table_name, {actor_id, asset_id}) do
      [{_key, level}] ->
        {:ok, level}

      [] ->
        :error
    end
  end

  @doc """
  Put a permission level in the cache.
  """
  def put(actor_id, asset_id, level) do
    :ets.insert(@table_name, {{actor_id, asset_id}, level})
    :ok
  end

  @doc """
  Invalidate all cache entries for an actor.
  """
  def invalidate_actor(actor_id) do
    # Invalidate locally
    GenServer.cast(__MODULE__, {:invalidate_actor, actor_id})

    # Broadcast to other nodes
    Phoenix.PubSub.broadcast(Core.PubSub, @pubsub_topic, {:invalidate_actor, actor_id})

    :ok
  end

  @doc """
  Invalidate all cache entries for an asset.
  """
  def invalidate_asset(asset_id) do
    # Invalidate locally
    GenServer.cast(__MODULE__, {:invalidate_asset, asset_id})

    # Broadcast to other nodes
    Phoenix.PubSub.broadcast(Core.PubSub, @pubsub_topic, {:invalidate_asset, asset_id})

    :ok
  end

  @doc """
  Invalidate all cache entries for a permission (actor + asset pair).
  """
  def invalidate_permission(actor_id, asset_id) do
    :ets.delete(@table_name, {actor_id, asset_id})
    :ok
  end

  @doc """
  Clear the entire cache. Useful for testing.
  """
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Get cache statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Create ETS table
    table =
      :ets.new(@table_name, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])

    # Subscribe to PubSub for multi-node invalidation
    Phoenix.PubSub.subscribe(Core.PubSub, @pubsub_topic)

    {:ok, %{table: table, hits: 0, misses: 0}}
  end

  @impl true
  def handle_cast({:invalidate_actor, actor_id}, state) do
    # Delete all entries for this actor
    # Use match_delete to remove all matching entries
    :ets.match_delete(@table_name, {{actor_id, :_}, :_})
    {:noreply, state}
  end

  def handle_cast({:invalidate_asset, asset_id}, state) do
    # Delete all entries for this asset
    # We need to iterate to find all entries with this asset_id
    # because asset_id is the second element of the key tuple
    delete_all_matching(asset_id)
    {:noreply, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, state}
  end

  def handle_call(:stats, _from, state) do
    size = :ets.info(@table_name, :size)
    {:reply, %{size: size, hits: state.hits, misses: state.misses}, state}
  end

  @impl true
  def handle_info({:invalidate_actor, actor_id}, state) do
    # Remote invalidation
    :ets.match_delete(@table_name, {{actor_id, :_}, :_})
    {:noreply, state}
  end

  def handle_info({:invalidate_asset, asset_id}, state) do
    # Remote invalidation
    delete_all_matching(asset_id)
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("Unexpected message in PermissionCache: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private functions

  # Delete all entries where the second element of the key matches the asset_id
  defp delete_all_matching(asset_id) do
    # Use a simple tabulation/list approach to find matching keys
    # since ETS match specs are complex
    :ets.foldl(
      fn {{actor_id, key_asset_id}, _level}, acc ->
        if key_asset_id == asset_id do
          :ets.delete(@table_name, {actor_id, asset_id})
        end
        acc
      end,
      :ok,
      @table_name
    )
  end
end
