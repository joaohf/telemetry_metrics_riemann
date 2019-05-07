defmodule TelemetryMetricsRiemann.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :telemetry_metrics_riemann,
      version: @version,
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: preferred_cli_env(),
      deps: deps(),
      dialyzer: [ignore_warnings: ".dialyzer_ignore"],
      docs: docs(),
      description: description(),
      package: package(),
      xref: xref(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib/", "test/support/"]
  defp elixirc_paths(_), do: ["lib/"]

  defp preferred_cli_env do
    [
      docs: :dev,
      dialyzer: :test,
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry_metrics, "~> 0.2"},
      {:dialyxir, "~> 0.5", only: :test, runtime: false},
      {:mox, "~> 0.5.0", only: :test, runtime: false},
      {:ex_doc, "~> 0.20.2", only: :dev},
      {:excoveralls, "~> 0.11", only: :test}
    ]
  end

  defp docs do
    [
      main: "TelemetryMetricsRiemann",
      canonical: "http://hexdocs.pm/telemetry_metrics_riemann",
      source_url: "https://github.com/joaohf/telemetry_metrics_riemann",
      source_ref: "v#{@version}"
    ]
  end

  defp description do
    """
    Telemetry.Metrics reporter for riemann-compatible metric servers
    """
  end

  defp package do
    [
      maintainers: ["João Henrique Ferreira de Freitas"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/joaohf/telemetry_metrics_riemann"}
    ]
  end

  defp xref do
    [exclude: [{Riemannx, :send, 0}]]
  end
end
