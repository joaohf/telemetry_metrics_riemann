defmodule TelemetryMetricsRiemann.Client do
  @callback format_events(any()) :: any()
  @callback publish_events(any()) :: :ok | {:ok, any()}

  @riemann_filter_fields [:ttl, :state, :time, :time_micros, :host]

  @spec format(%{
          attributes: nil | keyword() | map(),
          client: module(),
          host: String.t(),
          metric: Telemetry.Metrics.t(),
          prefix: String.t() | nil,
          tags: [Telemetry.Metrics.tag()],
          value: :telemetry.event_value()
        }) :: any()
  def format(%{
        client: client,
        host: host,
        prefix: prefix,
        metric: metric,
        value: value,
        tags: tags,
        attributes: attrs
      }) do
    event0 = get_common_riemann_fields(attrs, host)

    event1 = [
      service: format_metric_name(prefix, metric.name),
      description: metric.description,
      metric: value,
      tags: tags |> filter_fields |> format_tags,
      attributes: attrs |> filter_fields |> format_attrs
    ]

    List.flatten([event0, event1]) |> client.format_events
  end

  defp get_common_riemann_fields(attrs, host) do
    {Keyword.new(), attrs}
    |> maybe_get_ttl
    |> maybe_get_state
    |> maybe_get_time
    |> maybe_get_time_micros
    |> maybe_get_host(host)
    |> elem(0)
  end

  defp maybe_get_ttl({acc, attrs} = t) do
    case attrs[:ttl] do
      nil ->
        t

      value ->
        {Keyword.put(acc, :ttl, value), attrs}
    end
  end

  defp maybe_get_state({acc, attrs} = t) do
    case attrs[:state] do
      nil ->
        t

      value ->
        {Keyword.put(acc, :state, value), attrs}
    end
  end

  defp maybe_get_time({acc, attrs}) do
    case attrs[:time] do
      nil ->
        time = :erlang.system_time(:seconds)
        {Keyword.put(acc, :time, time), attrs}

      value ->
        {Keyword.put(acc, :time, value), attrs}
    end
  end

  defp maybe_get_time_micros({acc, attrs}) do
    case attrs[:time] do
      nil ->
        time = :erlang.system_time(:microsecond)
        {Keyword.put(acc, :time_micros, time), attrs}

      value ->
        {Keyword.put(acc, :time_micros, value), attrs}
    end
  end

  defp maybe_get_host({acc, attrs}, host) do
    case attrs[:host] do
      nil ->
        {Keyword.put(acc, :host, host), attrs}

      value ->
        {Keyword.put(acc, :host, value), attrs}
    end
  end

  defp filter_fields(fields) do
    Enum.filter(fields, fn
      {field, _value} ->
        field not in @riemann_filter_fields

      field ->
        field not in @riemann_filter_fields
    end)
  end

  defp format_tags(tags) do
    tags
  end

  defp format_attrs(attrs) do
    attrs
  end

  defp format_metric_name(nil, metric_name), do: format_metric_name(metric_name)
  defp format_metric_name(prefix, metric_name), do: format_metric_name([prefix | metric_name])

  defp format_metric_name(metric_name) do
    metric_name |> Enum.intersperse(".") |> Enum.map(&to_string/1) |> Enum.join()
  end
end
