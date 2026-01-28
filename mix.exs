defmodule PortfolioCore.MixProject do
  use Mix.Project

  @version "0.5.0"
  @source_url "https://github.com/nshkrdotcom/portfolio_core"

  def project do
    [
      app: :portfolio_core,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "PortfolioCore",
      source_url: @source_url,
      aliases: aliases(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:error_handling, :unknown, :unmatched_returns]
      ],
      test_coverage: [tool: ExCoveralls],
      test_ignore_filters: [~r{test/support/}]
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test.watch": :test,
        coveralls: :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PortfolioCore.Application, []}
    ]
  end

  defp deps do
    [
      # Core dependencies
      {:yaml_elixir, "~> 2.9"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.2"},
      {:nimble_options, "~> 1.0"},

      # Dev/test only
      {:ex_doc, "~> 0.40.0", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.2", only: [:dev, :test]},
      {:mox, "~> 1.1", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      {:supertester, "~> 0.5.1", only: :test}
    ]
  end

  defp description do
    "Hexagonal architecture core for building flexible RAG systems in Elixir."
  end

  defp package do
    [
      name: "portfolio_core",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["NSHKR"],
      files: ~w(lib guides assets .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "overview",
      source_url: @source_url,
      source_ref: "v#{@version}",
      assets: %{"assets" => "assets"},
      logo: "assets/portfolio_core.svg",
      extras: [
        # Overview
        {"README.md", [title: "Overview", filename: "overview"]},

        # Guides
        {"guides/getting-started.md", [title: "Getting Started", filename: "getting-started"]},
        {"guides/architecture.md", [title: "Architecture", filename: "architecture"]},
        {"guides/manifest-configuration.md",
         [title: "Manifest Configuration", filename: "manifest-configuration"]},
        {"guides/port-reference.md", [title: "Port Reference", filename: "port-reference"]},
        {"guides/writing-adapters.md", [title: "Writing Adapters", filename: "writing-adapters"]},
        {"guides/telemetry.md", [title: "Telemetry & Observability", filename: "telemetry"]},
        {"guides/testing.md", [title: "Testing", filename: "testing"]},

        # Reference
        {"examples/README.md", [title: "Examples", filename: "examples"]},
        {"CHANGELOG.md", [title: "Changelog", filename: "changelog"]},
        {"LICENSE", [title: "License", filename: "license"]}
      ],
      groups_for_extras: [
        Introduction: ["overview", "getting-started", "architecture"],
        Guides: [
          "manifest-configuration",
          "port-reference",
          "writing-adapters",
          "telemetry",
          "testing"
        ],
        Reference: ["examples", "changelog", "license"]
      ],
      groups_for_modules: [
        "Core Ports": ~r/PortfolioCore\.Ports\.(LLM|Embedder|Chunker|Retriever|Reranker)/,
        "Storage Ports": ~r/PortfolioCore\.Ports\.(VectorStore|DocumentStore|GraphStore)/,
        "Infrastructure Ports":
          ~r/PortfolioCore\.Ports\.(Cache|RateLimiter|Router|Pipeline|Agent$|AgentSession|Tool$)/,
        "Query Processing Ports":
          ~r/PortfolioCore\.Ports\.(QueryRewriter|QueryExpander|QueryDecomposer|CollectionSelector)/,
        "Evaluation Ports": ~r/PortfolioCore\.Ports\.(Evaluation|RetrievalMetrics)/,
        "VCS Ports": ~r/PortfolioCore\.Ports\.VCS/,
        Manifest: ~r/PortfolioCore\.Manifest/,
        Registry: ~r/PortfolioCore\.Registry/,
        Backend: ~r/PortfolioCore\.Backend/,
        Telemetry: ~r/PortfolioCore\.Telemetry/
      ]
    ]
  end

  defp aliases do
    [
      quality: ["format --check-formatted", "credo --strict", "dialyzer"],
      "test.all": ["quality", "test"]
    ]
  end
end
