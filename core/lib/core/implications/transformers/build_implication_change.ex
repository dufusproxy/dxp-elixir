defmodule Core.Implications.Transformers.BuildImplicationChange do
  @moduledoc """
  Transformer that injects Ash changes for creating implied assets.

  This transformer runs after the resource is compiled and adds
  `after_action` changes to the create action to automatically
  create implied assets. It also adds `before_action` changes to
  the destroy action to handle cascade deletion.
  """
  use Spark.Dsl.Transformer

  def before?(Ash.Resource.Transformers.Builtins), do: true
  def before?(_), do: false

  def transform(dsl_state) do
    implications = Spark.Dsl.Extension.get_entities(dsl_state, [:implications])

    if Enum.empty?(implications) do
      {:ok, dsl_state}
    else
      with {:ok, dsl_state} <- maybe_add_create_change(dsl_state, implications),
           {:ok, dsl_state} <- maybe_add_destroy_change(dsl_state, implications) do
        {:ok, dsl_state}
      else
        {:error, error} -> {:error, error}
      end
    end
  end

  defp maybe_add_create_change(dsl_state, implications) do
    case Ash.Resource.Info.primary_action(dsl_state, :create) do
      nil ->
        {:ok, dsl_state}

      %{name: action_name} ->
        case build_change_entity(:create, action_name, implications, dsl_state) do
          {:ok, change_entity} ->
            Spark.Dsl.Transformer.add_entity(
              dsl_state,
              [:actions, action_name, :changes],
              change_entity
            )

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp maybe_add_destroy_change(dsl_state, implications) do
    case Ash.Resource.Info.primary_action(dsl_state, :destroy) do
      nil ->
        {:ok, dsl_state}

      %{name: action_name} ->
        case build_change_entity(:destroy, action_name, implications, dsl_state) do
          {:ok, change_entity} ->
            Spark.Dsl.Transformer.add_entity(
              dsl_state,
              [:actions, action_name, :changes],
              change_entity
            )

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp build_change_entity(:create, _action_name, implications, dsl_state) do
    module = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)

    Spark.Dsl.Transformer.build_entity(
      Ash.Resource.Dsl,
      [:actions, :create],
      :change,
      change: {Core.Implications.Changes.CreateImpliedAssets,
               implications: implications, resource: module},
      only_when_valid?: true,
      description: "Automatically creates implied assets"
    )
  end

  defp build_change_entity(:destroy, _action_name, implications, dsl_state) do
    module = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)

    Spark.Dsl.Transformer.build_entity(
      Ash.Resource.Dsl,
      [:actions, :destroy],
      :change,
      change: {Core.Implications.Changes.HandleCascadeDelete,
               implications: implications, resource: module},
      only_when_valid?: true,
      description: "Handles cascade deletion of implied assets"
    )
  end
end
