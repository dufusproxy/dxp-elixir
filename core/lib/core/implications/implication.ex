defmodule Core.Implications.Implication do
  @moduledoc """
  Configuration for an asset implication.

  This struct stores the metadata for a single implication declaration
  in the `implications` DSL block.
  """
  defstruct [
    :asset_type,
    :default,
    :surfaced_as,
    :on_delete,
    :optional,
    :__identifier__,
    :__spark_metadata__
  ]

  @type t :: %__MODULE__{
          asset_type: atom(),
          default: :auto | map() | {module(), atom()} | nil,
          surfaced_as: :inline_field | :advanced_panel | :hidden,
          on_delete: :cascade | :convert_to_redirect | :orphan | :block,
          optional: boolean(),
          __identifier__: any(),
          __spark_metadata__: map()
        }

  @doc """
  Creates a new implication struct with defaults.
  """
  def new(opts) do
    struct(__MODULE__, opts)
  end

  @doc """
  Returns true if the implication should create an asset automatically.
  """
  def auto_create?(%__MODULE__{optional: false}), do: true
  def auto_create?(%__MODULE__{optional: true}), do: false

  @doc """
  Returns true if the implication should cascade deletion.
  """
  def cascade?(%__MODULE__{on_delete: :cascade}), do: true
  def cascade?(_), do: false

  @doc """
  Returns true if the implication should convert to redirect on deletion.
  """
  def convert_to_redirect?(%__MODULE__{on_delete: :convert_to_redirect}), do: true
  def convert_to_redirect?(_), do: false

  @doc """
  Returns true if the implication should orphan implied assets on deletion.
  """
  def orphan?(%__MODULE__{on_delete: :orphan}), do: true
  def orphan?(_), do: false

  @doc """
  Returns true if the implication should block deletion when implied assets exist.
  """
  def block?(%__MODULE__{on_delete: :block}), do: true
  def block?(_), do: false

  @doc """
  Returns true if the implication should be shown inline in the UI.
  """
  def inline_field?(%__MODULE__{surfaced_as: :inline_field}), do: true
  def inline_field?(_), do: false

  @doc """
  Returns true if the implication should be shown in an advanced panel.
  """
  def advanced_panel?(%__MODULE__{surfaced_as: :advanced_panel}), do: true
  def advanced_panel?(_), do: false

  @doc """
  Returns true if the implication should be hidden in the UI.
  """
  def hidden?(%__MODULE__{surfaced_as: :hidden}), do: true
  def hidden?(_), do: false
end
