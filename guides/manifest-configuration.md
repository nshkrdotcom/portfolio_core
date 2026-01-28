# Manifest Configuration

Manifests are YAML files that declaratively wire adapters to ports. The manifest engine loads, validates, and registers adapters at application start.

## Basic Structure

```yaml
version: "1.0"
environment: development

adapters:
  vector_store:
    adapter: MyApp.Adapters.Pgvector
    config:
      dimensions: 1536
      metric: cosine
    enabled: true

  embedder:
    adapter: MyApp.Adapters.OpenAIEmbedder
    config:
      model: text-embedding-3-small
      api_key: ${OPENAI_API_KEY}
```

## Schema Reference

The manifest is validated by `PortfolioCore.Manifest.Schema` using NimbleOptions. Here are all top-level keys:

### `version` (required)

Schema version string. Currently `"1.0"`.

```yaml
version: "1.0"
```

### `environment` (required)

Target environment. Converted to an atom.

```yaml
environment: development  # becomes :development
```

### `adapters` (required)

Map of port names to adapter configurations. Each adapter entry has:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `adapter` | atom (required) | -- | Module implementing the port behaviour |
| `config` | map or keyword | `%{}` | Adapter-specific configuration |
| `enabled` | boolean | `true` | Whether this adapter is active |

```yaml
adapters:
  embedder:
    adapter: MyApp.Embedder
    config:
      model: text-embedding-3-small
    enabled: true
```

### `router`

Router configuration for multi-provider LLM routing.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `strategy` | atom | -- | `:fallback`, `:round_robin`, `:specialist`, or `:cost_optimized` |
| `health_check_interval` | integer | `30000` | Health check interval in ms |
| `providers` | list of maps | -- | Provider configurations |

```yaml
router:
  strategy: fallback
  health_check_interval: 30000
  providers:
    - name: openai
      adapter: MyApp.OpenAI
      priority: 1
    - name: anthropic
      adapter: MyApp.Anthropic
      priority: 2
```

### `cache`

Cache layer configuration.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enabled` | boolean | `true` | Enable/disable caching |
| `backend` | atom | -- | `:ets`, `:redis`, or `:mnesia` |
| `default_ttl` | integer | `3600` | Default TTL in seconds |
| `namespaces` | map | -- | Per-namespace TTL overrides |

```yaml
cache:
  enabled: true
  backend: ets
  default_ttl: 3600
  namespaces:
    embeddings:
      ttl: 86400
```

### `agent`

Agent configuration for tool-using agents.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `max_iterations` | integer | `10` | Maximum tool loop iterations |
| `timeout` | integer | `300000` | Timeout in ms (5 minutes) |
| `tools` | list of atoms | -- | Available tool names |

```yaml
agent:
  max_iterations: 10
  timeout: 300000
  tools: [search, summarize, calculate]
```

### `pipelines`

Pipeline workflow configurations.

```yaml
pipelines:
  ingest:
    steps: [discover, chunk, embed, store]
  query:
    steps: [rewrite, expand, retrieve, rerank, generate]
```

### `graphs`

Graph database configurations.

```yaml
graphs:
  knowledge:
    adapter: MyApp.Neo4j
    config:
      url: bolt://localhost:7687
```

### `rag`

RAG strategy configuration.

```yaml
rag:
  strategy: adaptive
  retrieval:
    top_k: 10
    rerank: true
```

### `telemetry`

Telemetry configuration.

```yaml
telemetry:
  enabled: true
  log_level: debug
```

## Environment Variables

Any string value can reference environment variables with `${VAR_NAME}` syntax:

```yaml
config:
  api_key: ${OPENAI_API_KEY}
  base_url: ${API_BASE_URL:-https://api.openai.com}
```

### Syntax

| Pattern | Behavior |
|---------|----------|
| `${VAR}` | Expand to value; error if unset |
| `${VAR:-default}` | Expand to value; use `default` if unset |

Missing variables (without defaults) cause a startup error with a clear message identifying the missing variable.

## Loading and Reloading

### Automatic Loading

Configure the manifest path in your application config:

```elixir
config :portfolio_core, :manifest,
  manifest_path: "config/manifests/dev.yaml"
```

The engine loads the manifest during application startup.

### Manual Loading

```elixir
# Load from a specific path
:ok = PortfolioCore.Manifest.Engine.load("config/manifests/prod.yaml")

# Reload the current manifest
:ok = PortfolioCore.reload_manifest()

# Get the current manifest
manifest = PortfolioCore.manifest()
```

### Loading from Strings

Useful for testing:

```elixir
{:ok, manifest} = PortfolioCore.Manifest.Loader.load_string("""
version: "1.0"
environment: test
adapters:
  embedder:
    adapter: MyApp.MockEmbedder
    config: {}
""")
```

## Validation

The manifest is validated against the NimbleOptions schema on load. Access the schema programmatically:

```elixir
# Get the schema definition
schema = PortfolioCore.Manifest.Schema.schema_definition()

# Validate manually
{:ok, validated} = PortfolioCore.Manifest.Schema.validate(manifest_keyword_list)
```

Validation errors include the key path and expected type, making misconfiguration easy to diagnose.

## Per-Environment Manifests

A common pattern is to have separate manifests per environment:

```
config/manifests/
├── dev.yaml      # Local adapters, verbose logging
├── test.yaml     # Mock adapters, no external calls
└── prod.yaml     # Production adapters, real API keys
```

Then in your config files:

```elixir
# config/dev.exs
config :portfolio_core, :manifest,
  manifest_path: "config/manifests/dev.yaml"

# config/test.exs
config :portfolio_core, :manifest,
  manifest_path: "config/manifests/test.yaml"
```
