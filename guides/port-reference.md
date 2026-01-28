# Port Reference

This is the complete reference for all 18 port specifications defined by Portfolio Core. Each port is an Elixir behaviour that adapters implement.

## Storage Ports

### VectorStore

**Module:** `PortfolioCore.Ports.VectorStore`

Vector similarity search backends (Pgvector, Qdrant, Pinecone, etc.).

| Callback | Signature | Description |
|----------|-----------|-------------|
| `create_index/2` | `(index_id, config) -> :ok \| {:error, term}` | Create a vector index |
| `delete_index/1` | `(index_id) -> :ok \| {:error, term}` | Delete an index |
| `store/4` | `(index_id, id, vector, metadata) -> :ok \| {:error, term}` | Store a vector |
| `store_batch/2` | `(index_id, items) -> {:ok, count} \| {:error, term}` | Batch store |
| `search/4` | `(index_id, vector, k, opts) -> {:ok, results} \| {:error, term}` | Similarity search |
| `delete/2` | `(index_id, id) -> :ok \| {:error, term}` | Delete a vector |
| `index_stats/1` | `(index_id) -> {:ok, stats} \| {:error, term}` | Index statistics |
| `index_exists?/1` | `(index_id) -> boolean` | Check index exists (optional) |
| `fulltext_search/4` | `(index_id, query, k, opts) -> {:ok, results}` | Fulltext search (optional) |

**Key types:** `search_result` (id, score, metadata, vector), `index_config` (dimensions, metric, index_type), `distance_metric` (`:cosine`, `:euclidean`, `:dot_product`)

### VectorStore.Hybrid

**Module:** `PortfolioCore.Ports.VectorStore.Hybrid`

Extends VectorStore with combined semantic and fulltext search. Use `PortfolioCore.VectorStore.RRF.calculate_rrf_score/3` for Reciprocal Rank Fusion scoring.

### GraphStore

**Module:** `PortfolioCore.Ports.GraphStore`

Knowledge graph operations (Neo4j, Memgraph, etc.). Includes node/edge CRUD, traversal (BFS/DFS), and vector search on graph nodes.

### GraphStore.Community

**Module:** `PortfolioCore.Ports.GraphStore.Community`

GraphRAG community operations: `create_community/3`, `get_community_members/2`, `update_community_summary/3`, `list_communities/2`.

### DocumentStore

**Module:** `PortfolioCore.Ports.DocumentStore`

Document storage and retrieval. Handles raw documents with metadata before they are chunked and embedded.

## AI Ports

### Embedder

**Module:** `PortfolioCore.Ports.Embedder`

Text-to-vector embedding generation.

| Callback | Signature | Description |
|----------|-----------|-------------|
| `embed/2` | `(text, opts) -> {:ok, embedding_result} \| {:error, term}` | Embed single text |
| `embed_batch/2` | `(texts, opts) -> {:ok, batch_result} \| {:error, term}` | Batch embed |
| `dimensions/1` | `(model) -> pos_integer` | Output dimensions |
| `supported_models/0` | `() -> [model]` | List supported models |

**Key types:** `embedding_result` (vector, model, dimensions, token_count)

### LLM

**Module:** `PortfolioCore.Ports.LLM`

Language model completions. Stateless request/response -- no session state or tool loop.

| Callback | Signature | Description |
|----------|-----------|-------------|
| `complete/2` | `(messages, opts) -> {:ok, result} \| {:error, term}` | Chat completion |
| `stream/2` | `(messages, opts) -> {:ok, enumerable} \| {:error, term}` | Streaming completion |
| `supported_models/0` | `() -> [model]` | List supported models |
| `model_info/1` | `(model) -> model_info` | Model capabilities |

**Key types:** `message` (role, content), `completion_result` (content, model, usage, finish_reason, response_id)

**Options:** `:model`, `:max_tokens` (legacy), `:max_completion_tokens`, `:max_output_tokens`, `:temperature`, `:stop`, `:api`, `:store`, `:previous_response_id`

### Chunker

**Module:** `PortfolioCore.Ports.Chunker`

Document chunking strategies.

| Callback | Signature | Description |
|----------|-----------|-------------|
| `chunk/3` | `(text, format, config) -> {:ok, chunks} \| {:error, term}` | Split text |
| `estimate_chunks/2` | `(text, config) -> count` | Estimate chunk count |
| `supported_strategies/0` | `() -> [strategy]` | List strategies (optional) |

**Formats:** `:plain`, `:markdown`, `:code`, `:html`

**Strategies:** `:character`, `:sentence`, `:paragraph`, `:recursive`, `:semantic`, `:format_aware`

**Size units:** `:characters` (default), `:tokens` (for LLM context budgeting)

### Retriever

**Module:** `PortfolioCore.Ports.Retriever`

Retrieval strategy implementations. Includes capability detection (`supports_embedding?/0`, `supports_text_query?/0`).

### Reranker

**Module:** `PortfolioCore.Ports.Reranker`

Result reranking with score normalization (`normalize_scores/1`).

## Infrastructure Ports

### Router

**Module:** `PortfolioCore.Ports.Router`

Multi-provider LLM routing. Strategies: `:fallback`, `:round_robin`, `:specialist`, `:cost_optimized`.

Includes execute callbacks (`execute/2`, `execute_with_retry/2`) and `backend_capabilities` field on provider type.

### Cache

**Module:** `PortfolioCore.Ports.Cache`

Caching layer with compute-if-absent pattern (`compute_if_absent/3`) and pattern invalidation (`invalidate_pattern/2`).

### Pipeline

**Module:** `PortfolioCore.Ports.Pipeline`

Workflow step definitions with parallel execution (`parallel?/0`), error handling modes (`on_error/0`), timeout, and cache TTL.

### Agent

**Module:** `PortfolioCore.Ports.Agent`

Application-orchestrated tool-using agents. The application controls the tool loop: calling `execute_tool`, tracking iterations, managing memory.

Includes session-based API (`process/3`, `process_with_tools/4`).

### AgentSession

**Module:** `PortfolioCore.Ports.AgentSession`

Externally autonomous agent sessions for providers like Claude and Codex that control their own tool loop.

| Callback | Signature | Description |
|----------|-----------|-------------|
| `provider_name/0` | `() -> string` | Provider identifier |
| `capabilities/0` | `() -> {:ok, [capability]} \| {:error, term}` | Supported capabilities |
| `validate_config/1` | `(config) -> :ok \| {:error, term}` | Validate configuration |
| `start_session/2` | `(agent_id, opts) -> {:ok, session_id} \| {:error, term}` | Start session |
| `execute/3` | `(session_id, input, opts) -> {:ok, run_result} \| {:error, term}` | Execute a run |
| `cancel/2` | `(session_id, run_id) -> {:ok, run_id} \| {:error, term}` | Cancel a run |
| `end_session/1` | `(session_id) -> :ok \| {:error, term}` | End session |

**Key distinction:** AgentSession differs from Agent in that the provider controls the tool loop. The application starts a session, sends input, and observes events -- it does not orchestrate individual tool calls.

**Event types:** 22 canonical types across session, run, message, tool, and usage categories.

### Tool

**Module:** `PortfolioCore.Ports.Tool`

Individual tool definitions for agent tool loops.

### RateLimiter

**Module:** `PortfolioCore.Ports.RateLimiter`

Rate limiting for external API calls.

## Query Processing Ports

### QueryRewriter

**Module:** `PortfolioCore.Ports.QueryRewriter`

Query cleaning: removes greetings, filler phrases, extracts core question. `rewrite/2`.

### QueryExpander

**Module:** `PortfolioCore.Ports.QueryExpander`

Query expansion: adds synonyms, related terms, expands abbreviations. `expand/2`.

### QueryDecomposer

**Module:** `PortfolioCore.Ports.QueryDecomposer`

Multi-hop query decomposition: breaks complex questions into simpler sub-questions for parallel retrieval. `decompose/2`.

### CollectionSelector

**Module:** `PortfolioCore.Ports.CollectionSelector`

Query routing: selects relevant collections/indices for a query. `select/3` returns collection names with optional reasoning and confidence.

## Evaluation Ports

### Evaluation

**Module:** `PortfolioCore.Ports.Evaluation`

RAG quality evaluation using the RAG Triad (context relevance, groundedness, answer relevance) and hallucination detection.

| Callback | Signature | Description |
|----------|-----------|-------------|
| `evaluate_rag_triad/2` | `(result, opts) -> scores` | RAG Triad evaluation |
| `detect_hallucination/2` | `(result, opts) -> detection` | Hallucination detection |

### RetrievalMetrics

**Module:** `PortfolioCore.Ports.RetrievalMetrics`

IR quality metrics: Recall@K, Precision@K, MRR, Hit Rate@K.

| Callback | Signature | Description |
|----------|-----------|-------------|
| `compute/3` | `(expected, retrieved, opts) -> metrics` | Single test case |
| `aggregate/1` | `(results) -> aggregated` | Aggregate across cases |

## Version Control

### VCS

**Module:** `PortfolioCore.Ports.VCS`

Version control system abstraction (Git, Mercurial, SVN, etc.).

**Required callbacks (11):** `status/1`, `diff/3`, `diff_uncommitted/1`, `stage/2`, `stage_all/1`, `unstage/2`, `commit/3`, `log/2`, `show/2`, `current_branch/1`, `is_repo?/1`

**Optional callbacks (5):** `push/2`, `pull/2`, `branch_create/3`, `branch_delete/3`, `checkout/2`

**Key types:** `status` (changed/staged/untracked/deleted files, branch info, ahead/behind counts), `diff_result` (patch, stats), `commit` (hash, author, message, timestamp, parents), `error` (tagged tuples for all failure modes)
