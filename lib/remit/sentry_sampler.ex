defmodule Remit.SentrySampler do
  @moduledoc false

  def sample(%{transaction_context: %{attributes: attributes}}) do
    cond do
      # a root db span is a stray query outside any trace (Periodically cleanup)
      attributes[:"db.system"] -> 0.0
      # /revision is the k8s readiness probe.
      attributes[:"url.path"] == "/revision" -> 0.0
      true -> parent_decision()
    end
  end

  defp parent_decision do
    case :otel_ctx.get_value(:"sentry-trace", :undefined) do
      {_trace_id, _span_id, sampled} -> if sampled, do: 1.0, else: 0.0
      _ -> 1.0
    end
  end
end
