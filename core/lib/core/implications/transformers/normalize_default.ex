defmodule Core.Implications.Transformers.NormalizeDefault do
  @moduledoc """
  Transformer that normalizes the `default` option in implications.

  This transformer converts the `default` option into a consistent format
  that can be easily processed at runtime.
  """
  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    # This transformer is called per-entity, so we normalize during the
    # entity transform phase. The actual normalization happens in the
    # entity's transform option.
    {:ok, dsl_state}
  end
end
