defmodule TelemetryMetricsRiemann.Client.Riemannx do
  @moduledoc """
  This module implements an adapter to [riemannx](https://github.com/hazardfn/riemannx) riemann
  client.
  """

  @behaviour TelemetryMetricsRiemann.Client

  @impl true
  def format_events(event) do
    event
  end

  @impl true
  def publish_events(events) do
    Riemannx.send(events)
  end
end
