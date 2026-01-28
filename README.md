# Portfolio Core

<p align="center">
  <img src="assets/portfolio_core.svg" alt="Portfolio Core Logo" width="200">
</p>

<p align="center">
  <a href="https://hex.pm/packages/portfolio_core"><img alt="Hex.pm" src="https://img.shields.io/hexpm/v/portfolio_core.svg"></a>
  <a href="https://hexdocs.pm/portfolio_core"><img alt="Documentation" src="https://img.shields.io/badge/docs-hexdocs-purple.svg"></a>
  <a href="https://github.com/nshkrdotcom/portfolio_core/actions"><img alt="Build Status" src="https://img.shields.io/github/actions/workflow/status/nshkrdotcom/portfolio_core/ci.yml"></a>
  <a href="https://opensource.org/licenses/MIT"><img alt="License" src="https://img.shields.io/hexpm/l/portfolio_core.svg"></a>
</p>

**Hexagonal architecture core for building flexible RAG systems in Elixir. Port specifications, manifest-based configuration, adapter registry, and dependency injection framework.**

---

## Overview

Portfolio Core provides the foundational primitives for building RAG (Retrieval-Augmented Generation) systems using hexagonal (ports and adapters) architecture. It defines:

- **Port Specifications** - Elixir behaviours defining contracts for vector stores, graph databases, embedders, LLMs, and more
- **Manifest Engine** - YAML-based configuration with environment variable expansion
- **Adapter Registry** - ETS-backed runtime lookup for port implementations
- **Telemetry Integration** - Built-in observability hooks

## Features

### Port Specifications (18 total)

**Storage Ports:**
- `VectorStore` - Vector similarity search
- `VectorStore.Hybrid` - Hybrid semantic + fulltext search
- `GraphStore` - Knowledge graph operations
- `GraphStore.Community` - GraphRAG community operations
- `DocumentStore` - Document storage and retrieval

**AI Ports:**
- `Embedder` - Text embedding generation
- `LLM` - Language model completions
- `Chunker` - Document chunking strategies (supports token-based sizing)
- `Retriever` - Retrieval strategies
- `Reranker` - Result reranking

**Infrastructure Ports:**
- `Router` - Multi-provider LLM routing
- `Cache` - Caching layer abstraction
- `Pipeline` - Workflow step definitions
- `Agent` - Tool-using agent behavior
- `Tool` - Individual tool definitions

**Evaluation:**
- `Evaluation` - RAG quality evaluation (RAG Triad, hallucination detection)

**Agent Sessions (NEW in v0.5.0):**
- `AgentSession` - Stateful autonomous agent session management (Claude, Codex)

**Version Control (NEW in v0.5.0):**
- `VCS` - Version control system abstraction (Git, Mercurial, etc.)

## Installation

Add `portfolio_core` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:portfolio_core, "~> 0.5.0"}
  ]
end
```

## Quick Start

### 1. Define a Manifest

Create `config/manifests/development.yml`:

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

### 2. Implement an Adapter

```elixir
defmodule MyApp.Adapters.VectorStore.Pgvector do
  @behaviour PortfolioCore.Ports.VectorStore

  @impl true
  def create_index(index_id, config) do
    # Implementation
  end

  @impl true
  def store(index_id, id, vector, metadata) do
    # Implementation
  end

  @impl true
  def search(index_id, query_vector, k, opts) do
    # Implementation
  end

  # ... other callbacks
end
```

### 3. Use the Registry

```elixir
# Get adapter at runtime
{module, config} = PortfolioCore.adapter(:vector_store)

# Use the adapter
module.search("my_index", query_vector, 10, [])
```

## Token-Based Chunking (v0.3.1)

The `Chunker` port now supports a `size_unit` configuration option for token-aware chunking:

```elixir
# Character-based sizing (default)
config = %{
  chunk_size: 1000,
  chunk_overlap: 200,
  size_unit: :characters,
  separators: nil
}

# Token-based sizing (for LLM context windows)
config = %{
  chunk_size: 512,        # 512 tokens
  chunk_overlap: 50,      # 50 tokens overlap
  size_unit: :tokens,
  separators: nil
}

{:ok, chunks} = MyChunker.chunk(text, :markdown, config)
```

Adapters interpret `:tokens` using their own token estimation (typically ~4 characters per token).

## Enhanced Registry (v0.2.0)

The registry now supports:
- Adapter metadata and capabilities
- CrucibleIR-compatible backend capability metadata
- Health status tracking
- Call metrics and error rates

```elixir
# Register with capabilities
PortfolioCore.Registry.register(:llm, MyLLM, config, %{
  capabilities: [:generation, :streaming],
  backend_capabilities: %{
    backend_id: :openai,
    provider: "openai",
    models: ["gpt-4o-mini"],
    default_model: "gpt-4o-mini",
    supports_vision: true,
    cost_per_million_input: 5.0,
    cost_per_million_output: 15.0
  }
})

# Fetch backend capabilities (PortfolioCore.Backend.Capabilities)
{:ok, caps} = PortfolioCore.Registry.backend_capabilities(:llm)
backend_ir = PortfolioCore.Backend.Capabilities.to_backend_ir(caps)

# Find by capability
PortfolioCore.Registry.find_by_capability(:streaming)

# Health tracking
PortfolioCore.Registry.mark_unhealthy(:llm)
PortfolioCore.Registry.health_status(:llm)  # => :unhealthy
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Application                            │
├─────────────────────────────────────────────────────────────┤
│                    Portfolio Core                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │    Ports    │  │  Manifest   │  │      Registry       │  │
│  │ (Behaviours)│  │   Engine    │  │    (ETS-backed)     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                       Adapters                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │ Pgvector │ │  Neo4j   │ │  OpenAI  │ │ Anthropic│  ...   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Guides

Comprehensive documentation is available on [HexDocs](https://hexdocs.pm/portfolio_core) and in the `guides/` directory:

| Guide | Description |
|-------|-------------|
| [Getting Started](guides/getting-started.md) | Installation, first manifest, first adapter |
| [Architecture](guides/architecture.md) | Hexagonal architecture, module layout, design principles |
| [Manifest Configuration](guides/manifest-configuration.md) | Full YAML schema reference, env vars, per-environment setup |
| [Port Reference](guides/port-reference.md) | All 18 port specifications with callback signatures |
| [Writing Adapters](guides/writing-adapters.md) | Adapter patterns, capabilities, health tracking |
| [Telemetry & Observability](guides/telemetry.md) | Event catalogue, spans, metrics integration |
| [Testing](guides/testing.md) | Mox mocks, registry isolation, manifest testing |

Runnable examples are in `examples/` -- see the [Examples README](examples/README.md).

## Related Packages

- [`portfolio_index`](https://github.com/nshkrdotcom/portfolio_index) - Production adapters and pipelines
- [`portfolio_manager`](https://github.com/nshkrdotcom/portfolio_manager) - CLI and application layer

## License

MIT License - see [LICENSE](LICENSE) for details.
