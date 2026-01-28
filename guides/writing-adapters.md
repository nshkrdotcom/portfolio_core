# Writing Adapters

Adapters are Elixir modules that implement port behaviours. This guide covers patterns for writing, testing, and registering adapters.

## Basic Pattern

Every adapter follows the same structure:

```elixir
defmodule MyApp.Adapters.Embedder.OpenAI do
  @behaviour PortfolioCore.Ports.Embedder

  @impl true
  def embed(text, opts) do
    model = Keyword.get(opts, :model, "text-embedding-3-small")

    case call_openai_api(text, model) do
      {:ok, response} ->
        {:ok, %{
          vector: response["data"] |> List.first() |> Map.get("embedding"),
          model: model,
          dimensions: dimensions(model),
          token_count: response["usage"]["total_tokens"]
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def embed_batch(texts, opts) do
    # Batch implementation
  end

  @impl true
  def dimensions("text-embedding-3-small"), do: 1536
  def dimensions("text-embedding-3-large"), do: 3072

  @impl true
  def supported_models, do: ["text-embedding-3-small", "text-embedding-3-large"]

  defp call_openai_api(text, model) do
    # HTTP client call
  end
end
```

### Key rules

1. **Add `@behaviour`** to get compile-time callback checking
2. **Tag every callback with `@impl true`** to catch typos and missing implementations
3. **Return tagged tuples** -- `{:ok, result}` or `{:error, reason}` -- matching the port typespec
4. **Keep adapters thin** -- they should translate between the port contract and the external service, not contain business logic

## Registering Adapters

### Via Manifest (recommended)

The manifest engine automatically registers adapters on startup:

```yaml
adapters:
  embedder:
    adapter: MyApp.Adapters.Embedder.OpenAI
    config:
      model: text-embedding-3-small
      api_key: ${OPENAI_API_KEY}
```

### Manual Registration

For dynamic or test scenarios:

```elixir
PortfolioCore.Registry.register(
  :embedder,
  MyApp.Adapters.Embedder.OpenAI,
  [model: "text-embedding-3-small", api_key: "sk-..."],
  %{capabilities: [:embedding, :batch_embedding]}
)
```

The fourth argument is optional metadata used for capability discovery and health tracking.

## Backend Capabilities

If your adapter can report its capabilities, export a `capabilities/1` or `capabilities/0` function:

```elixir
defmodule MyApp.Adapters.LLM.OpenAI do
  @behaviour PortfolioCore.Ports.LLM

  def capabilities(_config) do
    %{
      backend_id: :openai,
      provider: "openai",
      models: ["gpt-4o", "gpt-4o-mini"],
      default_model: "gpt-4o-mini",
      supports_streaming: true,
      supports_tools: true,
      supports_vision: true,
      cost_per_million_input: 5.0,
      cost_per_million_output: 15.0
    }
  end

  # ... callbacks
end
```

This integrates with `PortfolioCore.Backend.Capabilities` and the registry's `backend_capabilities/2` function:

```elixir
{:ok, caps} = PortfolioCore.Registry.backend_capabilities(:llm)
caps.supports_streaming  # => true
caps.cost_per_million_input  # => 5.0

# Convert to CrucibleIR format (when available)
ir = PortfolioCore.Backend.Capabilities.to_backend_ir(caps)
```

## Metadata and Health Tracking

Register with metadata to enable capability discovery and health tracking:

```elixir
PortfolioCore.Registry.register(:llm, MyLLM, config, %{
  capabilities: [:generation, :streaming, :function_calling]
})

# Find adapters by capability
PortfolioCore.Registry.find_by_capability(:streaming)
# => [{:llm, MyLLM, config}]

# Health tracking
PortfolioCore.Registry.mark_unhealthy(:llm)
PortfolioCore.Registry.health_status(:llm)  # => :unhealthy
PortfolioCore.Registry.mark_healthy(:llm)

# Metrics
PortfolioCore.Registry.record_call(:llm, true)   # success
PortfolioCore.Registry.record_call(:llm, false)  # failure
{:ok, metrics} = PortfolioCore.Registry.metrics(:llm)
# => %{call_count: 2, error_count: 1, error_rate: 0.5, healthy: true, uptime: 3600}
```

## Testing with Mox

Define mocks in `test/support/mocks.ex`:

```elixir
Mox.defmock(MockEmbedder, for: PortfolioCore.Ports.Embedder)
Mox.defmock(MockLLM, for: PortfolioCore.Ports.LLM)
Mox.defmock(MockVectorStore, for: PortfolioCore.Ports.VectorStore)
```

Use them in tests:

```elixir
defmodule MyApp.SearchTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  test "search returns relevant results" do
    MockEmbedder
    |> expect(:embed, fn "What is Elixir?", _opts ->
      {:ok, %{vector: List.duplicate(0.1, 1536), model: "test", dimensions: 1536, token_count: 5}}
    end)

    MockVectorStore
    |> expect(:search, fn "my_index", _vector, 10, _opts ->
      {:ok, [%{id: "doc1", score: 0.95, metadata: %{title: "Elixir Guide"}, vector: nil}]}
    end)

    # Register mocks
    PortfolioCore.Registry.register(:embedder, MockEmbedder, [])
    PortfolioCore.Registry.register(:vector_store, MockVectorStore, [])

    # Test your code that uses the registry
    assert {:ok, results} = MyApp.Search.query("What is Elixir?")
    assert length(results) == 1
  end
end
```

## Adapter Patterns

### Wrapping External APIs

Keep HTTP concerns isolated:

```elixir
defmodule MyApp.Adapters.Embedder.OpenAI do
  @behaviour PortfolioCore.Ports.Embedder

  @impl true
  def embed(text, opts) do
    with {:ok, response} <- api_call("/embeddings", %{input: text, model: model(opts)}),
         {:ok, result} <- parse_response(response) do
      {:ok, result}
    end
  end

  defp model(opts), do: Keyword.get(opts, :model, "text-embedding-3-small")

  defp api_call(path, body) do
    # HTTP call
  end

  defp parse_response(response) do
    # Response parsing
  end
end
```

### Local/In-Memory Adapters

Useful for development and testing:

```elixir
defmodule MyApp.Adapters.VectorStore.InMemory do
  @behaviour PortfolioCore.Ports.VectorStore

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @impl true
  def create_index(index_id, config) do
    Agent.update(__MODULE__, &Map.put(&1, index_id, {config, %{}}))
    :ok
  end

  @impl true
  def store(index_id, id, vector, metadata) do
    Agent.update(__MODULE__, fn state ->
      update_in(state, [index_id, Access.elem(1)], &Map.put(&1, id, {vector, metadata}))
    end)
    :ok
  end

  @impl true
  def search(index_id, query_vector, k, _opts) do
    Agent.get(__MODULE__, fn state ->
      case Map.get(state, index_id) do
        nil -> {:error, :not_found}
        {_config, vectors} ->
          results =
            vectors
            |> Enum.map(fn {id, {vec, meta}} ->
              %{id: id, score: cosine_similarity(query_vector, vec), metadata: meta, vector: nil}
            end)
            |> Enum.sort_by(& &1.score, :desc)
            |> Enum.take(k)

          {:ok, results}
      end
    end)
  end

  # ... other callbacks
end
```

### Telemetry-Instrumented Adapters

Wrap calls with telemetry spans:

```elixir
defmodule MyApp.Adapters.Embedder.Instrumented do
  @behaviour PortfolioCore.Ports.Embedder

  @impl true
  def embed(text, opts) do
    PortfolioCore.Telemetry.span(
      [:portfolio, :embedder, :embed],
      %{model: Keyword.get(opts, :model, "unknown")},
      fn -> do_embed(text, opts) end
    )
  end

  defp do_embed(text, opts) do
    # Actual implementation
  end
end
```

## Running Examples

The `examples/` directory contains runnable adapter examples:

```bash
mix run examples/basic_port_usage.exs
mix run examples/custom_adapter.exs
mix run examples/ollama_llm_adapter.exs
```

See `examples/README.md` for the full list and prerequisites.
