defmodule TelemetryMetricsRiemannTest do
  import Mox

  use ExUnit.Case

  import ExUnit.CaptureLog

  setup :set_mox_global
  setup :verify_on_exit!

  test "counter metric is reported as riemann metric with 0 as a value" do
    counter = given_counter("http.requests", event_name: "http.request")

    start_reporter(metrics: [counter], client: RiemannClientMock)

    RiemannClientMock
    |> expect(:format_events, 1, fn event -> event end)
    |> expect(:publish_events, 1, fn [event] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "http.requests",
        description: nil,
        metric: 0,
        tags: [],
        attributes: []
      ] = event

      :ok
    end)

    :telemetry.execute([:http, :request], %{latency: 211})
  end

  test "last value metric is reported as riemann gauge with absolute value" do
    last_value = given_last_value("vm.memory.total")

    start_reporter(metrics: [last_value], client: RiemannClientMock)

    RiemannClientMock
    |> expect(:format_events, 3, fn event -> event end)
    |> expect(:publish_events, 1, fn [event] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "vm.memory.total",
        description: nil,
        metric: 2001,
        tags: [],
        attributes: []
      ] = event

      :ok
    end)
    |> expect(:publish_events, 1, fn [event] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "vm.memory.total",
        description: nil,
        metric: 1585,
        tags: [],
        attributes: []
      ] = event

      :ok
    end)
    |> expect(:publish_events, 1, fn [event] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "vm.memory.total",
        description: nil,
        metric: 1872,
        tags: [],
        attributes: []
      ] = event

      :ok
    end)

    :telemetry.execute([:vm, :memory], %{total: 2001})
    :telemetry.execute([:vm, :memory], %{total: 1585})
    :telemetry.execute([:vm, :memory], %{total: 1872})
  end

  test "riemann metric with tags and attributes" do
    counter =
      given_counter(
        "http.requests",
        event_name: "http.request",
        metadata: :all,
        tags: [:method, :status]
      )

    start_reporter(metrics: [counter], client: RiemannClientMock)

    RiemannClientMock
    |> expect(:format_events, 3, fn event -> event end)
    |> expect(:publish_events, 1, fn [event] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "http.requests",
        description: nil,
        metric: 0,
        tags: [:method, :status],
        attributes: [method: "GET", status: 200]
      ] = event

      :ok
    end)
    |> expect(:publish_events, 1, fn [event] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "http.requests",
        description: nil,
        metric: 0,
        tags: [:method, :status],
        attributes: [method: "POST", status: 201]
      ] = event

      :ok
    end)
    |> expect(:publish_events, 1, fn [event] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "http.requests",
        description: nil,
        metric: 0,
        tags: [:method, :status],
        attributes: [method: "GET", status: 404]
      ] = event

      :ok
    end)

    :telemetry.execute([:http, :request], %{latency: 172}, %{method: "GET", status: 200})
    :telemetry.execute([:http, :request], %{latency: 200}, %{method: "POST", status: 201})
    :telemetry.execute([:http, :request], %{latency: 198}, %{method: "GET", status: 404})
  end

  test "telemetry tags is convert to riemann fields" do
    counter =
      given_last_value("http.request.latency",
        tags: [:method, :status]
      )

    start_reporter(metrics: [counter], client: RiemannClientMock)

    RiemannClientMock
    |> expect(:format_events, 2, fn event -> event end)
    |> expect(:publish_events, 1, fn [event] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        state: "critical",
        ttl: 200,
        service: "http.request.latency",
        description: nil,
        metric: 172,
        tags: [:method, :status],
        attributes: []
      ] = event

      :ok
    end)
    |> expect(:publish_events, 1, fn [event] ->
      [
        host: "localhost",
        time_micros: _tm,
        time: 1000,
        service: "http.request.latency",
        description: nil,
        metric: 200,
        tags: [:method, :status],
        attributes: [status: 201]
      ] = event

      :ok
    end)

    :telemetry.execute([:http, :request], %{latency: 172}, %{state: "critical", ttl: 200})

    :telemetry.execute([:http, :request], %{latency: 200}, %{
      time: 1000,
      host: "localhost",
      status: 201
    })
  end

  test "there can be multiple metrics derived from the same event" do
    dist =
      given_distribution(
        "http.request.latency",
        buckets: [0, 100, 200, 300]
      )

    sum = given_sum("http.request.payload_size")

    start_reporter(metrics: [dist, sum], client: RiemannClientMock)

    RiemannClientMock
    |> expect(:format_events, 4, fn event -> event end)
    |> expect(:publish_events, 1, fn [event0, event1] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "http.request.payload_size",
        description: nil,
        metric: 121,
        tags: [],
        attributes: []
      ] = event1

      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "http.request.latency",
        description: nil,
        metric: 172,
        tags: [],
        attributes: []
      ] = event0

      :ok
    end)
    |> expect(:publish_events, 1, fn [event0, event1] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "http.request.latency",
        description: nil,
        metric: 200,
        tags: [],
        attributes: []
      ] = event0

      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "http.request.payload_size",
        description: nil,
        metric: 64,
        tags: [],
        attributes: []
      ] = event1

      :ok
    end)

    :telemetry.execute([:http, :request], %{latency: 172, payload_size: 121})
    :telemetry.execute([:http, :request], %{latency: 200, payload_size: 64})
  end

  test "measurement function is taken into account when getting the value for the metric" do
    last_value = given_last_value("vm.memory.total", measurement: fn m -> m.total * 2 end)

    start_reporter(metrics: [last_value], client: RiemannClientMock)

    RiemannClientMock
    |> expect(:format_events, 3, fn event -> event end)
    |> expect(:publish_events, 1, fn [event] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "vm.memory.total",
        description: nil,
        metric: 4002,
        tags: [],
        attributes: []
      ] = event

      :ok
    end)
    |> expect(:publish_events, 1, fn [event] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "vm.memory.total",
        description: nil,
        metric: 3170,
        tags: [],
        attributes: []
      ] = event

      :ok
    end)
    |> expect(:publish_events, 1, fn [event] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "vm.memory.total",
        description: nil,
        metric: 3744,
        tags: [],
        attributes: []
      ] = event

      :ok
    end)

    :telemetry.execute([:vm, :memory], %{total: 2001})
    :telemetry.execute([:vm, :memory], %{total: 1585})
    :telemetry.execute([:vm, :memory], %{total: 1872})
  end

  test "published metrics are prefixed with a provided prefix" do
    metrics = [
      given_counter("http.request.count"),
      given_distribution("http.request.latency", buckets: [0, 100, 200]),
      given_last_value("http.request.current_memory"),
      given_sum("http.request.payload_size")
    ]

    start_reporter(metrics: metrics, client: RiemannClientMock, prefix: "myapp")

    RiemannClientMock
    |> expect(:format_events, 4, fn event -> event end)
    |> expect(:publish_events, 1, fn [e1, e2, e3, e4] ->
      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "myapp.http.request.count",
        description: nil,
        metric: 0,
        tags: [],
        attributes: []
      ] = e1

      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "myapp.http.request.latency",
        description: nil,
        metric: 200,
        tags: [],
        attributes: []
      ] = e2

      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "myapp.http.request.current_memory",
        description: nil,
        metric: 200,
        tags: [],
        attributes: []
      ] = e3

      [
        host: _h,
        time_micros: _tm,
        time: _t,
        service: "myapp.http.request.payload_size",
        description: nil,
        metric: 200,
        tags: [],
        attributes: []
      ] = e4

      :ok
    end)

    :telemetry.execute([:http, :request], %{latency: 200, current_memory: 200, payload_size: 200})
  end

  test "invalid value is reported" do
    counter = given_last_value("http.requests", event_name: "http.request")

    start_reporter(metrics: [counter], client: RiemannClientMock)

    RiemannClientMock
    |> expect(:format_events, 0, fn event -> event end)
    |> expect(:publish_events, 0, fn _events -> :ok end)

    assert capture_log(fn ->
             :telemetry.execute([:http, :request], %{latency: :number})
             Process.sleep(100)
           end) =~ ~r/Failed to process metric/
  end

  describe "riemann client error handling" do
    test "notifying an error logs an error" do
      reporter = start_reporter(metrics: [], client: RiemannClientMock, prefix: "myapp")

      assert capture_log(fn ->
               TelemetryMetricsRiemann.client_error(reporter, "Failed to publish metric")
               Process.sleep(100)
             end) =~ ~r/Failed to publish metric/
    end

    test "notifying a UDP error for the same socket multiple times generates only one log" do
      counter = given_counter("http.requests", event_name: "http.request")

      start_reporter(metrics: [counter], client: RiemannClientMock)

      RiemannClientMock
      |> expect(:format_events, 1, fn event -> event end)
      |> expect(:publish_events, 1, fn _events ->
        {:error, "Failed to publish metric using riemann client mock"}
      end)

      assert capture_log(fn ->
               :telemetry.execute([:http, :request], %{latency: 211})
               Process.sleep(100)
             end) =~ ~r/Failed to publish metric using riemann client mock/
    end
  end

  defp given_counter(event_name, opts \\ []) do
    Telemetry.Metrics.counter(event_name, opts)
  end

  defp given_sum(event_name, opts \\ []) do
    Telemetry.Metrics.sum(event_name, opts)
  end

  defp given_last_value(event_name, opts \\ []) do
    Telemetry.Metrics.last_value(event_name, opts)
  end

  defp given_distribution(event_name, opts) do
    Telemetry.Metrics.distribution(event_name, opts)
  end

  defp start_reporter(options) do
    {:ok, pid} = TelemetryMetricsRiemann.start_link(options)
    pid
  end
end
