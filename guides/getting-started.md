# Getting Started

This guide walks you through installing Portfolio Core, configuring your first manifest, implementing an adapter, and using the registry to wire everything together.

## Prerequisites

- Elixir ~> 1.15
- Erlang/OTP 26+

## Installation

Add `portfolio_core` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:portfolio_core, "~> 0.5.0"}
  ]
end
```

Then fetch:

```bash
mix deps.get
```

Portfolio Core starts its supervision tree automatically. On boot it launches:

1. `PortfolioCore.Registry` -- ETS-backed adapter lookup table
2. `PortfolioCore.Manifest.Engine` -- loads and validates your manifest YAML

## Step 1: Create a Manifest

Create `config/manifests/dev.yaml`:

```yaml
version: "1.0"
environment: development

adapters:
  vector_store:
    adapter: MyApp.Adapters.VectorStore.Pgvector
    config:
      dimensions: 1536
      metric: cosine

  embedder:
    adapter: MyApp.Adapters.Embedder.OpenAI
    config:
      model: text-embedding-3-small
      api_key: ${OPENAI_API_KEY}
```

The `${OPENAI_API_KEY}` syntax is expanded from your shell environment at load time. You can also supply defaults with `${VAR:-fallback_value}`.

## Step 2: Point the Application at Your Manifest

In `config/config.exs` (or per-environment config files):

```elixir
config :portfolio_core, :manifest,
  manifest_path: "config/manifests/dev.yaml"
```

## Step 3: Implement an Adapter

Adapters are plain Elixir modules that implement a port behaviour:

```elixir
defmodule MyApp.Adapters.Embedder.OpenAI do
  @behaviour PortfolioCore.Ports.Embedder

  @impl true
  def embed(text, opts) do
    model = Keyword.get(opts, :model, "text-embedding-3-small")
    # Call OpenAI API, return {:ok, %{vector: [...], model: model, ...}}
  end

  @impl true
  def embed_batch(texts, opts) do
    # Batch embed
  end

  @impl true
  def dimensions("text-embedding-3-small"), do: 1536
  def dimensions("text-embedding-3-large"), do: 3072

  @impl true
  def supported_models, do: ["text-embedding-3-small", "text-embedding-3-large"]
end
```

See the [Writing Adapters](writing-adapters.html) guide for patterns, testing, and best practices.

## Step 4: Use the Registry

Once the application starts, adapters are wired automatically from your manifest. Access them at runtime:

```elixir
# Get adapter tuple
{module, config} = PortfolioCore.adapter(:embedder)

# Use it
{:ok, result} = module.embed("What is Elixir?", Keyword.new(config))

# Or use the bang variant
{module, config} = PortfolioCore.adapter!(:vector_store)
```

You can also interact with the registry directly for advanced operations:

```elixir
# List all registered ports
PortfolioCore.registered_ports()
# => [:embedder, :vector_store]

# Check registration
PortfolioCore.Registry.registered?(:embedder)
# => true

# Register manually (no manifest needed)
PortfolioCore.Registry.register(:llm, MyApp.LLM, [model: "gpt-4o"], %{
  capabilities: [:generation, :streaming]
})
```

## Step 5: Add Telemetry (Optional)

Attach handlers to observe adapter operations:

```elixir
:telemetry.attach_many(
  "my-portfolio-handler",
  PortfolioCore.Telemetry.events(),
  &MyApp.TelemetryHandler.handle_event/4,
  nil
)
```

See the [Telemetry & Observability](telemetry.html) guide for the full event catalogue.

## Next Steps

- [Architecture](architecture.html) -- understand hexagonal architecture and the ports & adapters pattern
- [Manifest Configuration](manifest-configuration.html) -- full manifest schema reference
- [Port Reference](port-reference.html) -- all 18 port specifications
- [Writing Adapters](writing-adapters.html) -- adapter patterns, testing with Mox, and registration
- [Telemetry & Observability](telemetry.html) -- events, spans, and metrics
- [Testing](testing.html) -- testing strategies with Mox and Supertester
