# TelemetryMetricsRiemann

[![CircleCI](https://circleci.com/gh/joaohf/telemetry_metrics_riemann.svg?style=svg)](https://circleci.com/gh/joaohf/telemetry_metrics_riemann)

`Telemetry.Metrics` reporter for riemann-compatible metric servers.

To use it, start the reporter with the `start_link/1` function, providing it a list of
`Telemetry.Metrics` metric definitions:

```elixir
import Telemetry.Metrics

TelemetryMetricsRiemann.start_link(
  metrics: [
    counter("http.request.count"),
    sum("http.request.payload_size"),
    last_value("vm.memory.total")
  ],
  client: TelemetryMetricsRiemann.Client.Riemannx
)
```

or put it under a supervisor:

```elixir
import Telemetry.Metrics

children = [
  {TelemetryMetricsStatsd, [
    metrics: [
      counter("http.request.count"),
      sum("http.request.payload_size"),
      last_value("vm.memory.total")
    ],
    client: TelemetryMetricsRiemann.Client.Riemannx
  ]}
]

Supervisor.start_link(children, ...)
```

This reporter formats every metric from telemetry to [riemann event](http://riemann.io/concepts.html) and sends using the `client`. A `client` means any supported riemann client. Currently the following riemann clients is supported:

 * [riemannx](https://github.com/hazardfn/riemannx)

You can also configure the prefix for all the published metrics using the `:prefix` option.

Note that the reporter doesn't aggregate metrics in-process - it sends metric updates to riemann whenever a relevant Telemetry event is emitted.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `telemetry_metrics_riemann` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:telemetry_metrics_riemann, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/telemetry_metrics_riemann](https://hexdocs.pm/telemetry_metrics_riemann).


## Copyright and License

TelemetryMetricsStatsd is copyright (c) 2019 João Henrique Ferreira de Freitas.

TelemetryMetricsStatsd source code is released under MIT license.

See [LICENSE](LICENSE) for more information.
