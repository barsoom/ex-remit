defmodule Remit.SentrySamplerTest do
  use ExUnit.Case, async: true

  defp sample(attributes \\ %{}) do
    Remit.SentrySampler.sample(%{transaction_context: %{attributes: attributes}})
  end

  test "drops k8s probes and stray root db spans" do
    assert sample(%{"db.system": "postgresql"}) == 0.0
    assert sample(%{"url.path": "/revision"}) == 0.0
  end

  test "samples everything else when there is no incoming trace" do
    assert sample(%{"url.path": "/api/stats"}) == 1.0
    assert sample() == 1.0
  end

  test "respects the parent sampling decision from an incoming sentry-trace header" do
    :otel_ctx.set_value(:"sentry-trace", {"8ea7ebdd71be4f29bc23434711a631ee", "a2270a7527074cdb", true})
    assert sample(%{"url.path": "/api/stats"}) == 1.0

    :otel_ctx.set_value(:"sentry-trace", {"8ea7ebdd71be4f29bc23434711a631ee", "a2270a7527074cdb", false})
    assert sample(%{"url.path": "/api/stats"}) == 0.0
  end
end
