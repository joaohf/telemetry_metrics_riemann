defmodule TelemetryMetricsRiemann do
  @moduledoc """
  `Telemetry.Metrics` reporter for riemann-compatible metric servers.

  To use it, start the reporter with the `start_link/1` function, providing it a list of
  `Telemetry.Metrics` metric definitions:

      import Telemetry.Metrics

      TelemetryMetricsStatsd.start_link(
        metrics: [
          counter("http.request.count"),
          sum("http.request.payload_size"),
          last_value("vm.memory.total")
        ]
      )

  > Note that in the real project the reporter should be started under a supervisor, e.g. the main
  > supervisor of your application.

  By default the reporter sends metrics to localhost:8125 - both hostname and port number can be
  configured using the `:host` and `:port` options.

  Note that the reporter doesn't aggregate metrics in-process - it sends metric updates to StatsD
  whenever a relevant Telemetry event is emitted.

  ## Translation between Telemetry.Metrics and riemann

  In this section we walk through how the Telemetry.Metrics metric definitions are mapped to riemannx metrics
  and their types at runtime

  Telemetry.Metrics names are translated as follows:

   * if the metric name was provided as a string, e.g. "http.request.count",
     it is sent to riemann server as-is
   * if the metric name was provided as a list of atoms, e.g. [:http, :request, :count],
     it is first converted to a string by joiging the segments with dots.
     In this example, the StatsD metric name would be "http.request.count" as well

  If the metric has tags, it is send to to riemann as tags.

  If the metric has tag value, it is converted to riemann attributes fields.

  Also, the following attributes, if present will be used to fill the riemann default fields protocol and consequently removed from attributes:

   * `host`
   * `state`
   * `ttl`
   * `time`
   * `time_micros`

  All metrics values from Telemetry.Metrics type is converted to riemann `metric` field. There is no special
  conversion rules. The riemann server, based on the configurations done, has an important role to convert/calculate each
  metric send by TelemetryMetricsRiemann. This reporter acts only as bridge to the [riemann protocol](http://riemann.io/concepts.html).

  ### Counter

  Telemetry.Metrics counter is simply represented as a riemann `metric`.
  Each event the metric is based on increments the counter by 1.

  ### Last value

  Last value metric is represented as a riemann `metric` value,
  whose values are always set to the value of the measurement from the most recent event.

  ### Sum

  Sum metric is also represented as a riemann `metric` value - the difference is that it always changes relatively and is never set to an absolute value.

  ### Distribution

  There is no distribution metric type in riemann equivalent to Telemetry.Metrics distribution.
  However, a distribution metric is also represented as a riemann `metric` value.

  ## Prefixing metric names

  Sometimes it's convenient to prefix all metric names with particular value, to group them by the name of the service,
  the host, or something else. You can use `:prefix` option to provide a prefix which will be
  prepended to all metrics published by the reporter.

  """

  use GenServer

  require Logger

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
  * `:client` - the module that implements riemann client interface
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
  def handle_cast({:client_error, reason}, state) do
    Logger.error("Failed to publish metrics using riemann client: #{inspect(reason)}")

    {:noreply, state}
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
