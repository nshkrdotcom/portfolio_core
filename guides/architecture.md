# Architecture

Portfolio Core implements a hexagonal (ports and adapters) architecture for building RAG systems. This guide explains the design decisions, module layout, and how the pieces fit together.

## Hexagonal Architecture

The core idea is simple: **business logic depends on abstractions (ports), never on concrete implementations (adapters)**. This gives you:

- **Swappable backends** -- switch from Pgvector to Qdrant by changing one line in your manifest
- **Testability** -- mock any port with Mox, no real databases or API keys needed
- **Isolation** -- adapter failures are contained; the core contract stays stable

```
┌─────────────────────────────────────────────────────────┐
│                   Your Application                       │
│                  (portfolio_manager)                      │
├─────────────────────────────────────────────────────────┤
│                   Portfolio Core                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │    Ports     │  │  Manifest   │  │    Registry     │ │
│  │ (Behaviours) │  │   Engine    │  │  (ETS-backed)   │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
├─────────────────────────────────────────────────────────┤
│                      Adapters                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │ Pgvector │ │  Neo4j   │ │  OpenAI  │ │ Anthropic│   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Module Structure

```
lib/portfolio_core/
├── application.ex          # OTP Application, starts supervision tree
├── registry.ex             # ETS-backed adapter registry (GenServer)
├── telemetry.ex            # Event definitions, span utilities
├── backend/
│   └── capabilities.ex     # CrucibleIR-compatible capability metadata
├── manifest/
│   ├── engine.ex           # GenServer: loads YAML, wires adapters
│   ├── loader.ex           # YAML parsing, env var expansion
│   └── schema.ex           # NimbleOptions validation schema
├── ports/
│   ├── vector_store.ex     # Vector similarity search
│   ├── vector_store/
│   │   └── hybrid.ex       # Hybrid semantic + fulltext
│   ├── graph_store.ex      # Knowledge graph operations
│   ├── graph_store/
│   │   └── community.ex    # GraphRAG community operations
│   ├── document_store.ex   # Document storage
│   ├── embedder.ex         # Embedding generation
│   ├── llm.ex              # Language model completions
│   ├── chunker.ex          # Document chunking
│   ├── retriever.ex        # Retrieval strategies
│   ├── reranker.ex         # Result reranking
│   ├── router.ex           # Multi-provider LLM routing
│   ├── cache.ex            # Caching layer
│   ├── pipeline.ex         # Workflow steps
│   ├── agent.ex            # Application-orchestrated agents
│   ├── agent_session.ex    # Externally autonomous agent sessions
│   ├── tool.ex             # Individual tool definitions
│   ├── evaluation.ex       # RAG quality evaluation
│   ├── vcs.ex              # Version control operations
│   ├── rate_limiter.ex     # Rate limiting
│   ├── collection_selector.ex  # Query routing to collections
│   ├── query_rewriter.ex   # Query cleaning
│   ├── query_expander.ex   # Query expansion
│   ├── query_decomposer.ex # Multi-hop query decomposition
│   └── retrieval_metrics.ex# IR quality metrics
└── vector_store/
    └── rrf.ex              # Reciprocal Rank Fusion scoring
```

## Supervision Tree

On application start, Portfolio Core creates a supervision tree:

```
PortfolioCore.Supervisor (one_for_one)
├── PortfolioCore.Registry          # Creates ETS table, manages adapter entries
└── PortfolioCore.Manifest.Engine   # Loads YAML, validates, registers adapters
```

The `Registry` starts first, creating the ETS table. Then the `Manifest.Engine` loads your YAML file, resolves adapter modules, validates config against the NimbleOptions schema, and registers each adapter in the ETS table.

## Data Flow

A typical request flows like this:

```
1. Application calls PortfolioCore.adapter(:embedder)
2. Registry does an ETS lookup → returns {module, config}
3. Application calls module.embed("text", opts)
4. Telemetry span wraps the call → emits :start, :stop/:exception events
5. Adapter calls external service (OpenAI, local model, etc.)
6. Result flows back through the same path
```

## Port Categories

Ports are grouped by responsibility:

| Category | Ports | Purpose |
|----------|-------|---------|
| **Storage** | VectorStore, VectorStore.Hybrid, GraphStore, GraphStore.Community, DocumentStore | Data persistence and search |
| **AI** | Embedder, LLM, Chunker, Retriever, Reranker | ML model interactions |
| **Infrastructure** | Router, Cache, Pipeline, Agent, Tool, RateLimiter | Orchestration and plumbing |
| **Query Processing** | QueryRewriter, QueryExpander, QueryDecomposer, CollectionSelector | Query transformation |
| **Evaluation** | Evaluation, RetrievalMetrics | Quality measurement |
| **Agent Sessions** | AgentSession | Autonomous agent management |
| **Version Control** | VCS | Git/VCS operations |

## Design Principles

### Portfolio Core provides contracts only

This package contains no concrete implementations, no database schemas, no API calls. It defines behaviours, validation schemas, and runtime infrastructure. Actual adapters live in separate packages (e.g., `portfolio_index`).

### Manifests are the single source of truth

All adapter wiring goes through a YAML manifest. This makes configuration declarative, environment-specific, and auditable. Environment variables keep secrets out of version control.

### The registry is the runtime bridge

ETS gives O(1) concurrent reads without GenServer bottlenecks. Any process in your application can look up an adapter without coordination. Health tracking and metrics are built in.

### Telemetry is opt-in but pervasive

Every adapter call can be wrapped in a telemetry span. Events follow a consistent naming convention. You choose what to observe by attaching handlers.

## Related Packages

- [`portfolio_index`](https://github.com/nshkrdotcom/portfolio_index) -- production adapter implementations (Pgvector, Neo4j, OpenAI, etc.)
- [`portfolio_manager`](https://github.com/nshkrdotcom/portfolio_manager) -- CLI, application layer, pipeline orchestration
