defmodule PortfolioCore do
  @moduledoc """
  Hexagonal architecture core for building flexible RAG systems in Elixir.

  PortfolioCore provides the foundational primitives for building
  Retrieval-Augmented Generation (RAG) systems using a ports and adapters
  (hexagonal) architecture.

  ## What This Package Provides

  - **Port Specifications** - Elixir behaviors defining contracts for adapters
  - **Manifest Engine** - YAML-based configuration for adapter wiring
  - **Adapter Registry** - Dynamic lookup of registered adapters
  - **Telemetry Integration** - Observability hooks for monitoring

  ## What This Package Does NOT Provide

  - No concrete adapter implementations (use `portfolio_index` for those)
  - No database schemas or migrations
  - No LLM/embedding API calls
  - No Broadway pipelines

  ## Architecture Overview

      ┌─────────────────────────────────────────┐
      │           YOUR APPLICATION              │
      │         (portfolio_manager)             │
      └─────────────────┬───────────────────────┘
                        │
      ┌─────────────────▼───────────────────────┐
      │            PORTFOLIO_CORE               │
      │  ┌───────────────────────────────────┐  │
      │  │           PORTS                   │  │
      │  │  VectorStore, GraphStore,         │  │
      │  │  Embedder, LLM, Chunker,          │  │
      │  │  Retriever, Reranker,             │  │
      │  │  DocumentStore, Router, Cache,    │  │
      │  │  Pipeline, Agent, Tool            │  │
      │  └───────────────────────────────────┘  │
      │  ┌───────────────────────────────────┐  │
      │  │      MANIFEST ENGINE              │  │
      │  │  YAML loading, validation,        │  │
      │  │  adapter wiring                   │  │
      │  └───────────────────────────────────┘  │
      │  ┌───────────────────────────────────┐  │
      │  │         REGISTRY                  │  │
      │  │  ETS-based adapter lookup         │  │
      │  └───────────────────────────────────┘  │
      └─────────────────┬───────────────────────┘
                        │
      ┌─────────────────▼───────────────────────┐
      │           PORTFOLIO_INDEX              │
      │  Concrete adapter implementations:     │
      │  Pgvector, Neo4j, OpenAI, Gemini, etc. │
      └─────────────────────────────────────────┘

  ## Quick Start

  1. Add `portfolio_core` to your dependencies:

      ```elixir
      defp deps do
        [{:portfolio_core, "~> 0.5.0"}]
      end
      ```

  2. Create a manifest file (`config/manifest.yaml`):

      ```yaml
      version: "1.0"
      environment: dev
      adapters:
        vector_store:
          adapter: MyApp.Adapters.Pgvector
          config:
            repo: MyApp.Repo
        embedder:
          adapter: MyApp.Adapters.OpenAI
          config:
            model: text-embedding-3-small
            api_key: ${OPENAI_API_KEY}
      ```

  3. Configure the manifest path:

      ```elixir
      config :portfolio_core, :manifest,
        manifest_path: "config/manifest.yaml"
      ```

  4. Use adapters in your code:

      ```elixir
      {adapter, config} = PortfolioCore.adapter!(:vector_store)
      adapter.search(config, index_id, query_vector, 10)
      ```

  ## Ports

  Ports are Elixir behaviors that define contracts for adapters:

  - `PortfolioCore.Ports.VectorStore` - Vector storage and similarity search
  - `PortfolioCore.Ports.VectorStore.Hybrid` - Hybrid semantic + fulltext search
  - `PortfolioCore.Ports.GraphStore` - Graph database operations
  - `PortfolioCore.Ports.GraphStore.Community` - GraphRAG community operations
  - `PortfolioCore.Ports.DocumentStore` - Document storage
  - `PortfolioCore.Ports.Embedder` - Embedding generation
  - `PortfolioCore.Ports.LLM` - Language model completions
  - `PortfolioCore.Ports.Chunker` - Document chunking
  - `PortfolioCore.Ports.Retriever` - Retrieval strategies
  - `PortfolioCore.Ports.Reranker` - Result reranking
  - `PortfolioCore.Ports.Router` - Multi-provider LLM routing
  - `PortfolioCore.Ports.Cache` - Caching layer abstraction
  - `PortfolioCore.Ports.Pipeline` - Pipeline step definitions
  - `PortfolioCore.Ports.Agent` - Tool-using agent behavior
  - `PortfolioCore.Ports.Tool` - Individual tool definitions
  - `PortfolioCore.Ports.Evaluation` - RAG quality evaluation
  - `PortfolioCore.Ports.VCS` - Version control system operations
  - `PortfolioCore.Ports.AgentSession` - Stateful autonomous agent sessions
  """

  alias PortfolioCore.Manifest.Engine

  @doc """
  Get the currently loaded manifest.

  ## Returns

    - The manifest as a keyword list
    - `nil` if no manifest is loaded

  ## Example

      manifest = PortfolioCore.manifest()
      version = Keyword.get(manifest, :version)
  """
  @spec manifest() :: keyword() | nil
  def manifest do
    Engine.get_manifest()
  end

  @doc """
  Get an adapter for the given port.

  ## Parameters

    - `port_name` - Atom identifying the port (e.g., `:vector_store`)

  ## Returns

    - `{module, config}` tuple for the adapter
    - `nil` if no adapter is registered

  ## Example

      {adapter, config} = PortfolioCore.adapter(:vector_store)
      adapter.search(config[:index], query_vector, 10)
  """
  @spec adapter(atom()) :: {module(), keyword() | map()} | nil
  def adapter(port_name) do
    case PortfolioCore.Registry.get(port_name) do
      {:ok, entry} -> {entry.module, entry.config}
      {:error, :not_found} -> nil
    end
  end

  @doc """
  Get an adapter for the given port, raising if not found.

  ## Parameters

    - `port_name` - Atom identifying the port

  ## Returns

    - `{module, config}` tuple for the adapter

  ## Raises

    - `ArgumentError` if no adapter is registered for the port

  ## Example

      {adapter, config} = PortfolioCore.adapter!(:embedder)
  """
  @spec adapter!(atom()) :: {module(), keyword() | map()}
  def adapter!(port_name) do
    entry = PortfolioCore.Registry.get!(port_name)
    {entry.module, entry.config}
  end

  @doc """
  List all registered port names.

  ## Returns

    - List of atoms representing registered ports

  ## Example

      PortfolioCore.registered_ports()
      # => [:vector_store, :embedder, :chunker]
  """
  @spec registered_ports() :: [atom()]
  def registered_ports do
    PortfolioCore.Registry.list_ports()
  end

  @doc """
  Reload the manifest from disk.

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure

  ## Example

      :ok = PortfolioCore.reload_manifest()
  """
  @spec reload_manifest() :: :ok | {:error, term()}
  def reload_manifest do
    Engine.reload()
  end
end
