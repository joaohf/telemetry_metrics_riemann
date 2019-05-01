defmodule TelemetryMetricsRiemann.Client.Riemannx do
  @moduledoc false

  @behaviour TelemetryMetricsRiemann.Client

  @impl true
  def format_events(event) do
    event
  end

  @impl true
  def publish_events(_events) do
    Riemannx.send()
  end
end
