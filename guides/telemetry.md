# Telemetry & Observability

Portfolio Core emits structured telemetry events for every major operation. This guide covers the event catalogue, how to attach handlers, and how to instrument your own adapters.

## Event Naming Convention

Events follow two namespaces:

- **`[:portfolio, :component, :operation, :phase]`** -- current standard
- **`[:portfolio_core, :component, :operation, :phase]`** -- legacy (still emitted)

Phases are `:start`, `:stop`, and `:exception`.

## Attaching Handlers

Subscribe to all events at once:

```elixir
:telemetry.attach_many(
  "my-handler",
  PortfolioCore.Telemetry.events(),
  &MyApp.TelemetryHandler.handle_event/4,
  nil
)
```

Or subscribe to a specific component:

```elixir
:telemetry.attach_many(
  "embedder-metrics",
  PortfolioCore.Telemetry.events_for(:embedder),
  &MyApp.EmbedderMetrics.handle_event/4,
  nil
)
```

Available components for `events_for/1`: `:embedder`, `:vector_store`, `:llm`, `:rag`, `:evaluation`, `:router`, `:cache`, `:agent`, `:graph`.

## Event Catalogue

### Embedder Events

| Event | Measurements | Metadata |
|-------|-------------|----------|
| `[:portfolio, :embedder, :embed, :start]` | `%{system_time: integer}` | `%{text: string}` |
| `[:portfolio, :embedder, :embed, :stop]` | `%{duration: native_time}` | `%{result: :ok}` |
| `[:portfolio, :embedder, :embed, :exception]` | `%{duration: native_time}` | `%{kind: :error, reason: exception}` |
| `[:portfolio, :embedder, :embed_batch, :start]` | `%{system_time: integer}` | batch metadata |
| `[:portfolio, :embedder, :embed_batch, :stop]` | `%{duration: native_time}` | batch metadata |
| `[:portfolio, :embedder, :embed_batch, :exception]` | `%{duration: native_time}` | error metadata |

### Vector Store Events

| Event | Measurements | Metadata |
|-------|-------------|----------|
| `[:portfolio, :vector_store, :search, :start\|:stop\|:exception]` | duration/time | search metadata |
| `[:portfolio, :vector_store, :insert, :start\|:stop\|:exception]` | duration/time | insert metadata |
| `[:portfolio, :vector_store, :insert_batch, :start\|:stop\|:exception]` | duration/time | batch metadata |

### LLM Events

| Event | Measurements | Metadata |
|-------|-------------|----------|
| `[:portfolio, :llm, :complete, :start\|:stop\|:exception]` | duration/time | completion metadata |

### RAG Pipeline Events

| Event | Description |
|-------|-------------|
| `[:portfolio, :rag, :rewrite, :start\|:stop\|:exception]` | Query rewriting |
| `[:portfolio, :rag, :expand, :start\|:stop\|:exception]` | Query expansion |
| `[:portfolio, :rag, :decompose, :start\|:stop\|:exception]` | Query decomposition |
| `[:portfolio, :rag, :select, :start\|:stop\|:exception]` | Collection selection |
| `[:portfolio, :rag, :search, :start\|:stop\|:exception]` | Retrieval search |
| `[:portfolio, :rag, :rerank, :start\|:stop\|:exception]` | Result reranking |
| `[:portfolio, :rag, :answer, :start\|:stop\|:exception]` | Answer generation |
| `[:portfolio, :rag, :self_correct, :start\|:stop\|:exception]` | Self-correction |

### Evaluation Events

| Event | Description |
|-------|-------------|
| `[:portfolio, :evaluation, :run, :start\|:stop\|:exception]` | Evaluation run |
| `[:portfolio, :evaluation, :test_case, :start\|:stop]` | Individual test case |

### Legacy Events

| Event | Description |
|-------|-------------|
| `[:portfolio_core, :manifest, :loaded]` | Manifest loaded |
| `[:portfolio_core, :manifest, :reload]` | Manifest reloaded |
| `[:portfolio_core, :manifest, :error]` | Manifest error |
| `[:portfolio_core, :adapter, :call, :start\|:stop\|:exception]` | Adapter call |
| `[:portfolio_core, :registry, :register]` | Adapter registered |
| `[:portfolio_core, :registry, :lookup]` | Registry lookup |
| `[:portfolio_core, :router, :route, :start\|:stop\|:exception]` | Router routing |
| `[:portfolio_core, :router, :health_check]` | Router health check |
| `[:portfolio_core, :cache, :get, :hit\|:miss]` | Cache get |
| `[:portfolio_core, :cache, :put]` | Cache put |
| `[:portfolio_core, :cache, :delete]` | Cache delete |
| `[:portfolio_core, :agent, :run, :start\|:stop]` | Agent run |
| `[:portfolio_core, :agent, :tool, :execute]` | Tool execution |
| `[:portfolio_core, :evaluation, :rag_triad, :start\|:stop\|:exception]` | RAG Triad eval |
| `[:portfolio_core, :evaluation, :hallucination, :start\|:stop\|:exception]` | Hallucination detection |
| `[:portfolio_core, :graph_store, :traverse, :start\|:stop]` | Graph traversal |
| `[:portfolio_core, :graph_store, :vector_search, :start\|:stop]` | Graph vector search |
| `[:portfolio_core, :graph_store, :community, :create\|:update_summary]` | Community ops |

## Instrumenting Your Code

### Using `span/3` (recommended)

Wraps a function with `:start`, `:stop`, and `:exception` events:

```elixir
PortfolioCore.Telemetry.span(
  [:portfolio, :embedder, :embed],
  %{model: "text-embedding-3-small", text_length: String.length(text)},
  fn -> do_embed(text) end
)
```

### Using `with_span` macro (legacy)

Prefixes events with `:portfolio_core`:

```elixir
require PortfolioCore.Telemetry

PortfolioCore.Telemetry.with_span [:search], %{query: query} do
  do_search(query)
end
# Emits: [:portfolio_core, :search, :start], [:portfolio_core, :search, :stop]
```

### Using `measure/3`

Measures duration and emits a single event:

```elixir
PortfolioCore.Telemetry.measure([:search], %{query: query}, fn ->
  do_search(query)
end)
```

### Emitting custom events

```elixir
PortfolioCore.Telemetry.emit(
  [:my_component, :operation],
  %{duration: 150, count: 10},
  %{source: "custom"}
)
# Emits: [:portfolio_core, :my_component, :operation]
```

## Example Handler

```elixir
defmodule MyApp.TelemetryHandler do
  require Logger

  def handle_event(
    [:portfolio, :embedder, :embed, :stop],
    %{duration: duration},
    metadata,
    _config
  ) do
    ms = System.convert_time_unit(duration, :native, :millisecond)
    Logger.info("Embedding completed in #{ms}ms", metadata: metadata)
  end

  def handle_event(
    [:portfolio, :embedder, :embed, :exception],
    %{duration: duration},
    %{reason: reason},
    _config
  ) do
    ms = System.convert_time_unit(duration, :native, :millisecond)
    Logger.error("Embedding failed after #{ms}ms: #{Exception.message(reason)}")
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
```

## Integration with Telemetry Libraries

Portfolio Core events work with standard Erlang/Elixir telemetry libraries:

- **`telemetry_metrics`** -- define metrics (counters, summaries, distributions) from events
- **`telemetry_poller`** -- periodic measurements
- **Phoenix LiveDashboard** -- visualize metrics in real time
- **PromEx** -- export to Prometheus

```elixir
# Example with telemetry_metrics
defmodule MyApp.Telemetry do
  import Telemetry.Metrics

  def metrics do
    [
      counter("portfolio.embedder.embed.stop.duration"),
      summary("portfolio.embedder.embed.stop.duration", unit: {:native, :millisecond}),
      counter("portfolio.vector_store.search.stop.duration"),
      distribution("portfolio.llm.complete.stop.duration",
        unit: {:native, :millisecond},
        buckets: [100, 500, 1000, 2000, 5000]
      )
    ]
  end
end
```
