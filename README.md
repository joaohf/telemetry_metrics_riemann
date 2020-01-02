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
  {TelemetryMetricsRiemann, [
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

This reporter formats every metric from telemetry to [riemann event](http://riemann.io/concepts.html) and sends using the `client`. A `client` means any supported riemann client. Currently the following riemann clients are supported:

 * [riemannx](https://github.com/hazardfn/riemannx)
 * [katja](https://github.com/joaohf/katja)

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

## Riemann clients

Telemetry.Metrics.Riemann has a relaxed dependency from a riemann client. The main reason is to do not impose any riemann client; so you are free to use any client.

You need to add one of the supported riemann client as dependency and configure it properly. Or provide an `TelemetryMetricsRiemann.Client` behaviour implementation.

## Riemannx

Add [riemannx](https://hex.pm/packages/riemannx) to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:riemannx, "~> 4.0"}
  ]
end
```

Follow the procedures to add a valid [riemannx configuration](https://hexdocs.pm/riemannx/readme.html#3-examples) to your application.

## Katja

Add [katja](https://hex.pm/packages/katja) to your list of dependencies in `rebar.config`:

```erlang
{deps, [
        {katja, "0.10.0"}
]}.
```

Follow the procedures to add a valid [katja configuration](https://github.com/joaohf/katja#configuration) to your application.


## Copyright and License

TelemetryMetricsRiemann is copyright (c) 2020 João Henrique Ferreira de Freitas.

TelemetryMetricsRiemann source code is released under MIT license.

See [LICENSE](LICENSE) for more information.

## Credits

The TelemetryMetricsRiemann was based on [TelemetryMetricsStatsd](https://github.com/arkgil/telemetry_metrics_statsd)