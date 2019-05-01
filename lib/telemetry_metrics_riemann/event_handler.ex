defmodule TelemetryMetricsRiemann.EventHandler do
  @moduledoc false

  alias Telemetry.Metrics

  @spec attach(
          [Metrics.t()],
          reporter :: pid(),
          client :: module(),
          prefix :: String.t() | nil,
          host :: String.t()
        ) :: [
          :telemetry.handler_id()
        ]
  def attach(metrics, reporter, client, prefix, host) do
    metrics_by_event = Enum.group_by(metrics, & &1.event_name)

    for {event_name, metrics} <- metrics_by_event do
      handler_id = handler_id(event_name, reporter)

      :ok =
        :telemetry.attach(handler_id, event_name, &__MODULE__.handle_event/4, %{
          reporter: reporter,
          metrics: metrics,
          client: client,
          prefix: prefix,
          host: host
        })

      handler_id
    end
  end

  @spec detach([:telemetry.handler_id()]) :: :ok
  def detach(handler_ids) do
    for handler_id <- handler_ids do
      :telemetry.detach(handler_id)
    end

    :ok
  end

  @spec handle_event(any(), any(), any(), %{
          client: any(),
          host: any(),
          metrics: any(),
          prefix: any(),
          reporter: any()
        }) :: :ok
  def handle_event(_event, measurements, metadata, %{
        reporter: reporter,
        metrics: metrics,
        client: client,
        prefix: prefix,
        host: host
      }) do
    packets =
      for metric <- metrics do
        case fetch_measurement(metric, measurements) do
          {:ok, value} ->
            opts = %{
              attributes: metric.tag_values.(metadata),
              tags: metric.tags,
              metric: metric,
              value: value,
              client: client,
              prefix: prefix,
              host: host
            }

            TelemetryMetricsRiemann.Client.format(opts)

          :error ->
            :nopublish
        end
      end
      |> Enum.filter(fn l -> check_metric(reporter, l) end)

    case packets do
      [] ->
        :ok

      packets ->
        publish_metrics(reporter, client, packets)
    end
  end

  @spec handler_id(:telemetry.event_name(), reporter :: pid) :: :telemetry.handler_id()
  defp handler_id(event_name, reporter) do
    {__MODULE__, reporter, event_name}
  end

  @spec fetch_measurement(Metrics.t(), :telemetry.event_measurements()) ::
          {:ok, number()} | :error
  defp fetch_measurement(%Metrics.Counter{}, _measurements) do
    # For counter, we can ignore the measurements and just use 0.
    {:ok, 0}
  end

  defp fetch_measurement(metric, measurements) do
    value =
      case metric.measurement do
        fun when is_function(fun, 1) ->
          fun.(measurements)

        key ->
          measurements[key]
      end

    cond do
      is_number(value) ->
        {:ok, value}

      true ->
        :error
    end
  end

  @spec publish_metrics(pid(), module(), [any()]) :: :ok
  defp publish_metrics(reporter, client, packets) do
    case client.publish_events(packets) do
      :ok ->
        :ok

      {:error, reason} ->
        TelemetryMetricsRiemann.client_error(reporter, reason)
        :ok
    end
  end

  defp check_metric(reporter, :nopublish) do
    TelemetryMetricsRiemann.client_error(reporter, "Failed to process metric")
    false
  end

  defp check_metric(_, _) do
    true
  end
end
