defmodule Remit.SentrySampler do
  @moduledoc false

  # /revision is the k8s readiness probe.
  def sample(%{transaction_context: %{attributes: attributes}}) do
    case attributes[:"url.path"] do
      "/revision" -> 0.0
      _ -> 1.0
    end
  end
end
