# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `PortfolioCore.Ports.VCS` behaviour for version control system abstraction
  - 11 required callbacks: status, diff, diff_uncommitted, stage, stage_all, unstage, commit, log, show, current_branch, is_repo?
  - 5 optional callbacks: push, pull, branch_create, branch_delete, checkout
  - Comprehensive type specifications: repo, commit_hash, ref, status, diff_result, diff_stats, commit, error
  - Full documentation with usage examples

## [0.4.0] - 2026-01-08

### Added
- `PortfolioCore.Backend.Capabilities` struct for CrucibleIR-compatible capability metadata
  - `from_metadata/2`, `from_adapter/4` - Build from metadata or adapter modules
  - `to_backend_ir/1` - Convert to CrucibleIR struct when available
- `PortfolioCore.Registry.backend_capabilities/2` - Adapter capability discovery
- New examples: DocumentStore, GraphStore, Ollama LLM/Embedder adapters
- Enhanced registry example with live OpenAI adapter

### Changed
- `Router.provider` type now includes `backend_capabilities` field

## [0.3.1] - 2025-12-30

### Added

- `PortfolioCore.Ports.CollectionSelector` behaviour for query routing
  - `select/3` - Select relevant collections for a query
  - Returns selected collection names with optional reasoning and confidence score
  - Enables intelligent routing of queries to appropriate data sources
- `PortfolioCore.Telemetry` - Extended telemetry event definitions and span utilities
  - New `[:portfolio, ...]` namespace for standardized events
  - `span/3` function for wrapping operations with start/stop/exception events
  - `events_for/1` to get events for specific components (embedder, llm, rag, etc.)
  - Event definitions for: embedder, vector_store, llm, rag, evaluation
- `PortfolioCore.Ports.RetrievalMetrics` behaviour for IR quality metrics
  - `compute/3` - Calculate metrics for a single test case (expected vs retrieved chunks)
  - `aggregate/1` - Aggregate metrics across multiple test cases
  - Metrics: Recall@K, Precision@K, MRR, Hit Rate@K
- `PortfolioCore.Ports.QueryRewriter` behaviour for query cleaning
  - `rewrite/2` - Transform conversational input into clean search queries
  - Removes greetings, filler phrases, and extracts core question
- `PortfolioCore.Ports.QueryExpander` behaviour for query expansion
  - `expand/2` - Add synonyms and related terms for better recall
  - Expands abbreviations and acronyms
- `PortfolioCore.Ports.QueryDecomposer` behaviour for multi-hop queries
  - `decompose/2` - Break complex questions into simpler sub-questions
  - Enables parallel retrieval for multi-faceted queries
- Chunker port `size_unit` type and config field
  - `size_unit :: :characters | :tokens` - Specifies how chunk sizes are measured
  - Enables token-based chunking for LLM context window budgeting
  - Adapters interpret `:tokens` using their own token estimation

### Changed

- `Chunker.chunk_config` type now includes optional `size_unit` field

## [0.3.0] - 2025-12-28

### Added
- `PortfolioCore.Ports.Evaluation` - RAG quality evaluation port
  - `evaluate_rag_triad/2` - Context relevance, groundedness, answer relevance
  - `detect_hallucination/2` - Hallucination detection
- GraphStore community operations for GraphRAG support
  - `traverse/3` - BFS/DFS graph traversal
  - `vector_search/3` - Embedding-based node search
  - `create_community/3` - Community creation
  - `get_community_members/2` - Member retrieval
  - `update_community_summary/3` - LLM summary storage
  - `list_communities/2` - Community enumeration
- Chunker byte position tracking (`start_byte`, `end_byte`)
- Chunker strategy type union and `supported_strategies/0` callback
- Retriever capability detection (`supports_embedding?/0`, `supports_text_query?/0`)
- VectorStore fulltext search (`fulltext_search/4`)
- VectorStore RRF score calculation (`calculate_rrf_score/3`)
- Pipeline parallel execution (`parallel?/0`)
- Pipeline error handling modes (`on_error/0`)
- Pipeline timeout and cache TTL (`timeout/0`, `cache_ttl/0`)
- Router execute callbacks (`execute/2`, `execute_with_retry/2`)
- Reranker score normalization (`normalize_scores/1`)
- Cache compute-if-absent pattern (`compute_if_absent/3`)
- Cache pattern invalidation (`invalidate_pattern/2`)
- Agent session-based API (`process/3`, `process_with_tools/4`)
- New telemetry events for evaluation and community operations

### Changed
- `Chunker.chunk` type now includes `start_byte` and `end_byte` fields
- `Retriever.retrieved_item` type now includes `id` field
- `Reranker.reranked_item` type now includes `id` field
- Port count increased from 13 to 14

## [0.2.0] - 2025-12-27

### Added
- `PortfolioCore.Ports.Router` - Multi-provider LLM routing behavior
- `PortfolioCore.Ports.Cache` - Caching layer behavior
- `PortfolioCore.Ports.Pipeline` - Pipeline step behavior
- `PortfolioCore.Ports.Agent` - Tool-using agent behavior
- `PortfolioCore.Ports.Tool` - Individual tool behavior
- Enhanced Registry with metadata, capabilities, health tracking, and metrics
- New manifest schema fields: `router`, `cache`, `agent`
- New telemetry events for router, cache, and agent operations

### Changed
- Registry.register/3 now accepts optional metadata parameter
- Manifest schema expanded with new configuration sections

## [0.1.1] - 2025-12-27

### Added

- Default value support for environment variables with `${VAR:-default}` syntax
- RAG strategy configuration field in manifest schema

### Changed

- Enhanced environment variable regex to support default value syntax

## [0.1.0] - 2025-12-26

### Added

- Initial release of PortfolioCore
- Port specifications (Elixir behaviors) for:
  - `VectorStore` - Vector similarity search backends
  - `GraphStore` - Knowledge graph database operations
  - `DocumentStore` - Document storage and retrieval
  - `Embedder` - Text embedding generation
  - `LLM` - Large language model completions
  - `Chunker` - Document chunking strategies
  - `Retriever` - Retrieval strategy implementations
  - `Reranker` - Result reranking
- Manifest engine with:
  - YAML configuration loading
  - Environment variable expansion (`${VAR}` syntax)
  - NimbleOptions-based schema validation
  - Hot reload support
- Adapter registry with:
  - ETS-backed storage for concurrent access
  - Dynamic adapter lookup
  - Port registration and unregistration
- Telemetry integration:
  - Span macros for measuring operations
  - Standard event definitions
  - Observable adapter calls
- Application supervisor for process management
- Comprehensive test suite with Mox mocks
- Runnable examples in `examples/` directory
- Documentation with ExDoc

### Notes

- This is a foundational library providing only port specifications
- Concrete adapter implementations should use `portfolio_index` package
- No database schemas, migrations, or external API calls included

[Unreleased]: https://github.com/nshkrdotcom/portfolio_core/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/nshkrdotcom/portfolio_core/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/nshkrdotcom/portfolio_core/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/nshkrdotcom/portfolio_core/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/nshkrdotcom/portfolio_core/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/nshkrdotcom/portfolio_core/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/nshkrdotcom/portfolio_core/releases/tag/v0.1.0
