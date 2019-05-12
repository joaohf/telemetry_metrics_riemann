defmodule TelemetryMetricsRiemann do
  @moduledoc """
  `Telemetry.Metrics` reporter for riemann-compatible metric servers.

  To use it, start the reporter with the `start_link/1` function, providing it a list of
  `Telemetry.Metrics` metric definitions:

      import Telemetry.Metrics

      TelemetryMetricsRiemann.start_link(
        metrics: [
          counter("http.request.count"),
          sum("http.request.payload_size"),
          last_value("vm.memory.total")
        ]
      )

  > Note that in the real project the reporter should be started under a supervisor, e.g. the main
  > supervisor of your application.

  By default the reporter formats and delegates the metrics to a riemann client which will send the metrics
  to a configured riemann server.

  Note that the reporter doesn't aggregate metrics in-process - it sends metric updates to riemann
  whenever a relevant Telemetry event is emitted.

  ## Translation between Telemetry.Metrics and riemann

  In this section we walk through how the Telemetry.Metrics metric definitions are mapped to riemann metrics
  and their types at runtime.

  Telemetry.Metrics names are translated as follows:

   * if the event name was provided as a string, e.g. "http.request.count",
     it is sent to riemann server as-is (using the `service` field)
   * if the event name was provided as a list of atoms, e.g. [:http, :request, :count],
     it is first converted to a string by joiging the segments with dots.
     In this example, the riemann `service` name would be "http.request.count" as well

  If the metric has tags, it is send to to riemann as `tags`.

  If the metric has tag value, it is converted to riemann `attributes` fields.

  Also, the following attributes, if present will be used to fill the riemann default fields protocol and consequently removed from attributes:

   * `host`, a hostname
   * `state`, any string which represents a state "ok", "critical", "online"
   * `ttl`, a floating-point-time, in seconds, that this event is considered valid for
   * `time`, the time of the event, in unix epoch time
   * `time_micros`, the time of the event, in microseconds

  All metrics values from Telemetry.Metrics type is converted to riemann `metric` field. There is no special
  conversion rules. The riemann server, based on the configurations done, has an important role to convert/calculate each
  metric send by TelemetryMetricsRiemann. This reporter acts only as bridge to the [riemann protocol](http://riemann.io/concepts.html).

  The following table shows how `Telemetry.Metrics` metrics map riemann metrics:

  | Telemetry.Metrics | riemann |
  |-------------------|--------|
  | `last_value`      | `metric` field, always set to an absolute value |
  | `counter`         | `metric` field, always increased by 1 |
  | `sum`             | `metric` field, increased and decreased by the provided value |
  | `summary`         | `metric` field recording individual measurement |
  | `histogram`       | `metric` field recording individual measurement |

  ### Counter

  Telemetry.Metrics counter is simply represented as a riemann `metric`.
  Each event the metric is based on increments the counter by 1.

  Example, given the metric definition:

      counter("http.request.count")

  and the event

      :telemetry.execute([:http, :request], %{duration: 120})

  the following riemann event would be sent to riemann server

      [service: "http.requests.count", metric: 1]

  ### Last value

  Last value metric is represented as a riemann `metric` value,
  whose values are always set to the value of the measurement from the most recent event.

  Example, given the metric definition:

      last_value("vm.memory.total")

  and the event

      :telemetry.execute([:vm, :memory], %{total: 1024})

  the following riemann event would be sent to riemann server

      [service: "vm.memory.total", metric: 1024]

  ### Sum

  Sum metric is also represented as a riemann `metric` value - the difference is that it always changes relatively and is never set to an absolute value.

  Example, given the metric definition:

      sum("http.request.payload_size")

  and the event

      :telemetry.execute([:http, :request], %{payload_size: 1076})

  the following riemann event would be sent to riemann server

      [service: "http.request.payload_size", metric: +1024]

  When the measurement is negative, the riemann metric is decreased accordingly.

  ### Summary

  Summary metric is also represented as a riemann `metric` value - the difference is that it always changes relatively and is never set to an absolute value.

  Example, given the metric definition:

      summary("http.request.duration")

  and the event

      :telemetry.execute([:http, :request], %{duration: 120})

  the following riemann event would be sent to riemann server

      [service: "http.request.duration", metric: 120]

  ### Distribution

  There is no distribution metric type in riemann equivalent to Telemetry.Metrics distribution.
  However, a distribution metric is also represented as a riemann `metric` value.

  Example, given the metric definition:

      distribution("http.request.duration", buckets: [0])

  and the event

      :telemetry.execute([:http, :request], %{duration: 120})

  the following riemann event would be sent to riemann server

      [service: "http.request.duration", metric: 120]

  Since histograms are configured on the riemann server side (for example using [riemann folds](https://riemann.io/api/riemann.folds.html)),
  the `:buckets` option has no effect when used with this reporter.

  ## Prefixing metric names

  Sometimes it's convenient to prefix all metric names with particular value, to group them by the name of the service,
  the host, or something else. You can use `:prefix` option to provide a prefix which will be
  prepended to all metrics published by the reporter.

  """

  use GenServer

  alias Telemetry.Metrics
  alias TelemetryMetricsRiemann.EventHandler

  @type option ::
          {:client, Atom}
          | {:metrics, [Metrics.t()]}
          | {:prefix, String.t()}
  @type options :: [option]

  @doc """
  Reporter's child spec.

  This function allows you to start the reporter under a supervisor like this:

      children = [
        {TelemetryMetricsRiemann, options}
      ]

  See `start_link/1` for a list of available options.
  """
  @spec child_spec(options) :: Supervisor.child_spec()
  def child_spec(options) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [options]}}
  end

  @doc """
  Starts a reporter and links it to the calling process.

  The available options are:
  * `:metrics` - a list of Telemetry.Metrics metric definitions which will be published by the
    reporter
  * `:client` - the module that implements riemann client interface: `TelemetryMetricsRiemann.Riemannx` or
    `TelemetryMetricsRiemann.Katja`
  * `:prefix` - a prefix prepended to the name of each metric published by the reporter. Defaults
    to `nil`.

  You can read more about all the options in the `TelemetryMetricsRiemann` module documentation.

  ## Example

      import Telemetry.Metrics

      TelemetryMetricsRiemann.start_link(
        metrics: [
          counter("http.request.count"),
          sum("http.request.payload_size"),
          last_value("vm.memory.total")
        ],
        prefix: "my-service",
        client: TelemetryMetricsRiemann.Riemannx
      )
  """
  @spec start_link(options) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @doc false
  @spec client_error(pid(), reason :: term) :: :ok
  def client_error(reporter, reason) do
    GenServer.cast(reporter, {:client_error, reason})
  end

  @impl true
  def init(options) do
    host = options |> Keyword.get(:host) |> maybe_get_hostname()
    metrics = Keyword.fetch!(options, :metrics)
    client = Keyword.get(options, :client)
    prefix = Keyword.get(options, :prefix)

    Process.flag(:trap_exit, true)
    handler_ids = EventHandler.attach(metrics, self(), client, prefix, host)

    {:ok, %{handler_ids: handler_ids, client: client}}
  end

  @impl true
  def handle_cast({:client_error, _reason} = msg, state) do
    {:stop, msg, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  @impl true
  def terminate(_reason, state) do
    EventHandler.detach(state.handler_ids)

    :ok
  end

  defp maybe_get_hostname(nil) do
    :inet.gethostname() |> elem(1) |> List.to_string()
  end

  defp maybe_get_hostname(host) when is_list(host) do
    List.to_string(host)
  end

  defp maybe_get_hostname(host) when is_binary(host) do
    host
  end

  defp maybe_get_hostname(host) do
    raise ArgumentError, message: "The #{inspect(host)} is invalid"
  end
end
