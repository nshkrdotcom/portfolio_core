# Testing

Portfolio Core is designed for testability. Every port can be mocked, the registry supports per-test isolation, and the manifest loader works with strings for in-test configuration.

## Mox Setup

### Define Mocks

Create `test/support/mocks.ex`:

```elixir
# Define a mock for each port you use
Mox.defmock(MockEmbedder, for: PortfolioCore.Ports.Embedder)
Mox.defmock(MockLLM, for: PortfolioCore.Ports.LLM)
Mox.defmock(MockVectorStore, for: PortfolioCore.Ports.VectorStore)
Mox.defmock(MockChunker, for: PortfolioCore.Ports.Chunker)
Mox.defmock(MockRetriever, for: PortfolioCore.Ports.Retriever)
Mox.defmock(MockReranker, for: PortfolioCore.Ports.Reranker)
Mox.defmock(MockDocumentStore, for: PortfolioCore.Ports.DocumentStore)
Mox.defmock(MockCache, for: PortfolioCore.Ports.Cache)
Mox.defmock(MockRouter, for: PortfolioCore.Ports.Router)
Mox.defmock(MockAgent, for: PortfolioCore.Ports.Agent)
Mox.defmock(MockEvaluation, for: PortfolioCore.Ports.Evaluation)
```

Ensure the file is compiled in `mix.exs`:

```elixir
def project do
  [
    # ...
    elixirc_paths: elixirc_paths(Mix.env())
  ]
end

defp elixirc_paths(:test), do: ["lib", "test/support"]
defp elixirc_paths(_), do: ["lib"]
```

### Use in Tests

```elixir
defmodule MyApp.RAGPipelineTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  test "RAG pipeline processes a query end-to-end" do
    query = "What is pattern matching?"
    embedding = List.duplicate(0.1, 1536)

    # Set up expectations
    MockEmbedder
    |> expect(:embed, fn ^query, _opts ->
      {:ok, %{vector: embedding, model: "test", dimensions: 1536, token_count: 5}}
    end)

    MockVectorStore
    |> expect(:search, fn "docs", ^embedding, 5, _opts ->
      {:ok, [
        %{id: "chunk_1", score: 0.92, metadata: %{text: "Pattern matching in Elixir..."}, vector: nil},
        %{id: "chunk_2", score: 0.87, metadata: %{text: "The match operator =..."}, vector: nil}
      ]}
    end)

    MockLLM
    |> expect(:complete, fn messages, _opts ->
      assert Enum.any?(messages, &(&1.role == :user))
      {:ok, %{content: "Pattern matching is...", model: "test", usage: %{input_tokens: 100, output_tokens: 50}, finish_reason: :stop}}
    end)

    # Register mocks
    PortfolioCore.Registry.register(:embedder, MockEmbedder, [])
    PortfolioCore.Registry.register(:vector_store, MockVectorStore, [])
    PortfolioCore.Registry.register(:llm, MockLLM, [])

    # Run the pipeline
    assert {:ok, answer} = MyApp.RAG.query(query)
    assert answer =~ "Pattern matching"
  end
end
```

## Registry Isolation

For async tests, each test should have its own registry state. Clear the registry in your setup:

```elixir
setup do
  PortfolioCore.Registry.clear()
  :ok
end
```

### Supertester Integration

Portfolio Core includes Supertester support for ETS table isolation. This is used internally for testing the registry without shared state conflicts:

```elixir
# The Registry exposes a test helper for table overrides
PortfolioCore.Registry.__supertester_set_table__(:table_name, my_isolated_table)
```

## Testing Adapters

When testing your own adapter implementations, test against the behaviour contract:

```elixir
defmodule MyApp.Adapters.OpenAIEmbedderTest do
  use ExUnit.Case, async: true

  alias MyApp.Adapters.Embedder.OpenAI, as: Adapter

  describe "embed/2" do
    test "returns embedding result with correct shape" do
      # This test requires OPENAI_API_KEY
      case System.get_env("OPENAI_API_KEY") do
        nil ->
          :skip

        _key ->
          assert {:ok, result} = Adapter.embed("Hello world", [])
          assert is_list(result.vector)
          assert length(result.vector) == result.dimensions
          assert is_binary(result.model)
          assert result.token_count > 0
      end
    end

    test "returns error for empty text" do
      assert {:error, _reason} = Adapter.embed("", [])
    end
  end

  describe "dimensions/1" do
    test "returns correct dimensions for known models" do
      assert Adapter.dimensions("text-embedding-3-small") == 1536
    end
  end

  describe "supported_models/0" do
    test "returns a non-empty list" do
      models = Adapter.supported_models()
      assert is_list(models)
      assert length(models) > 0
    end
  end
end
```

## Testing Manifests

Load manifests from strings for deterministic tests:

```elixir
test "manifest loads and wires adapters" do
  {:ok, manifest} = PortfolioCore.Manifest.Loader.load_string("""
  version: "1.0"
  environment: test
  adapters:
    embedder:
      adapter: MockEmbedder
      config:
        model: test-model
  """)

  assert manifest["version"] == "1.0"
end
```

Validate schema compliance:

```elixir
test "manifest validates required fields" do
  assert {:error, _} = PortfolioCore.Manifest.Schema.validate(
    version: "1.0",
    # missing :environment and :adapters
  )
end

test "manifest validates strategy values" do
  assert {:ok, :fallback} = PortfolioCore.Manifest.Schema.validate_strategy(:fallback, [:fallback, :round_robin])
  assert {:error, _} = PortfolioCore.Manifest.Schema.validate_strategy(:invalid, [:fallback, :round_robin])
end
```

## Testing Telemetry Events

Verify that your code emits the expected telemetry events:

```elixir
test "embed emits telemetry span" do
  ref = make_ref()
  pid = self()

  :telemetry.attach(
    "test-embed-#{inspect(ref)}",
    [:portfolio, :embedder, :embed, :stop],
    fn _event, measurements, _metadata, _config ->
      send(pid, {:telemetry, ref, measurements})
    end,
    nil
  )

  # Trigger the operation
  MockEmbedder
  |> expect(:embed, fn _text, _opts ->
    {:ok, %{vector: [0.1], model: "test", dimensions: 1, token_count: 1}}
  end)

  PortfolioCore.Telemetry.span([:portfolio, :embedder, :embed], %{}, fn ->
    MockEmbedder.embed("test", [])
  end)

  assert_receive {:telemetry, ^ref, %{duration: duration}}
  assert duration > 0

  :telemetry.detach("test-embed-#{inspect(ref)}")
end
```

## Test Configuration

In `config/test.exs`, point to a test manifest or skip manifest loading:

```elixir
# Option 1: Use a test-specific manifest
config :portfolio_core, :manifest,
  manifest_path: "config/manifests/test.yaml"

# Option 2: No manifest (register adapters manually in tests)
config :portfolio_core, :manifest, []
```

## Tips

- Use `async: true` on test modules that don't share global state
- Call `PortfolioCore.Registry.clear()` in setup blocks to avoid test pollution
- Use `Mox.stub/3` for default behaviors that multiple tests share
- Use `Mox.expect/3` for specific assertions about call arguments
- Test error paths -- verify adapters handle `{:error, reason}` returns correctly
- For integration tests with real APIs, use environment variable guards and tag with `@tag :integration`
