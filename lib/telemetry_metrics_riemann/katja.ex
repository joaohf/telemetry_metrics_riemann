defmodule TelemetryMetricsRiemann.Client.Katja do
  @moduledoc """
  This module implements an adapter to [Katja](https://github.com/joaohf/katja) riemann
  client.
  """

  @behaviour TelemetryMetricsRiemann.Client

  @impl true
  def format_events(event) do
    Keyword.update(event, :attributes, [], &convert_attributes/1)
  end

  @impl true
  def publish_events(events) do
    :katja.send_events(events)
  end

  defp convert_attributes([]) do
    []
  end

  defp convert_attributes(attributes) do
    for {key, value} <- attributes do
      {Atom.to_string(key), to_string(value)}
    end
  end
end
