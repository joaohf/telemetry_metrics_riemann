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

  TBD

  ### Counter

  TBD

  ### Last value

  TBD

  ### Sum

  TBD

  ### Distribution

  TBD

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
