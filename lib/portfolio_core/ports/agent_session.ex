defmodule PortfolioCore.Ports.AgentSession do
  @moduledoc """
  Port specification for stateful AI agent session management.

  This port defines the contract for managing externally autonomous agent
  sessions -- agents like Claude or Codex that control their own tool loop.
  It supports starting sessions, executing multi-turn agent runs, observing
  events, cancelling runs, and ending sessions.

  ## Distinction from Other Ports

  - **`PortfolioCore.Ports.LLM`** - Stateless request/response. Send messages,
    get a completion back. No session state, no tool loop.

  - **`PortfolioCore.Ports.Agent`** - Application-orchestrated RAG agents.
    The application controls the tool loop (calling `execute_tool`, tracking
    iterations, managing memory).

  - **`PortfolioCore.Ports.AgentSession`** (this port) - Externally autonomous
    agents. The agent provider controls the tool loop. The application starts
    a session, sends input, and observes events as the agent works autonomously.
    Sessions are stateful and persist across multiple runs.

  ## Session Lifecycle

      start_session/2 -> execute/3 (repeatable) -> end_session/1
                         cancel/2 (during execute)

  ## Event-Driven Observation

  During `execute/3`, adapters emit events via the `:event_callback` option,
  allowing consumers to observe the agent's autonomous execution in real time.

  ## Example Implementation

      defmodule MyApp.Adapters.ClaudeSession do
        @behaviour PortfolioCore.Ports.AgentSession

        @impl true
        def provider_name, do: "claude"

        @impl true
        def capabilities do
          {:ok, [
            %{name: "chat", type: :tool, enabled: true},
            %{name: "code_execution", type: :code_execution, enabled: true}
          ]}
        end

        @impl true
        def start_session(agent_id, opts) do
          # Initialize a session with the provider
          {:ok, "session_" <> generate_id()}
        end

        @impl true
        def execute(session_id, input, opts) do
          # Send input to the autonomous agent and collect results
          {:ok, %{output: "result", token_usage: %{input_tokens: 10, output_tokens: 20}, turn_count: 1, events: []}}
        end

        @impl true
        def cancel(session_id, run_id) do
          # Cancel an in-progress run
          {:ok, run_id}
        end

        @impl true
        def end_session(session_id) do
          # Clean up session resources
          :ok
        end

        @impl true
        def validate_config(config) do
          if Map.has_key?(config, :api_key), do: :ok, else: {:error, "api_key required"}
        end
      end
  """

  # ===========================================================================
  # Type Definitions
  # ===========================================================================

  @typedoc "Unique identifier for an agent session."
  @type session_id :: String.t()

  @typedoc "Unique identifier for a single execution run within a session."
  @type run_id :: String.t()

  @typedoc "Identifier for the agent type or configuration."
  @type agent_id :: String.t()

  @typedoc "Current status of a session."
  @type session_status ::
          :pending | :active | :paused | :completed | :failed | :cancelled

  @typedoc "Current status of a run."
  @type run_status ::
          :pending | :running | :completed | :failed | :cancelled | :timeout

  @typedoc "Type of capability an agent can have."
  @type capability_type ::
          :tool
          | :resource
          | :prompt
          | :sampling
          | :file_access
          | :network_access
          | :code_execution

  @typedoc """
  A capability describing what an agent can do.

  Matches the structure defined in `AgentSessionManager.Core.Capability`.
  """
  @type capability :: %{
          required(:name) => String.t(),
          required(:type) => capability_type(),
          optional(:enabled) => boolean(),
          optional(:description) => String.t(),
          optional(:config) => map(),
          optional(:permissions) => [String.t()]
        }

  @typedoc "Type of event emitted during session and run lifecycle."
  @type event_type ::
          :session_created
          | :session_started
          | :session_paused
          | :session_resumed
          | :session_completed
          | :session_failed
          | :session_cancelled
          | :run_started
          | :run_completed
          | :run_failed
          | :run_cancelled
          | :run_timeout
          | :message_sent
          | :message_received
          | :message_streamed
          | :tool_call_started
          | :tool_call_completed
          | :tool_call_failed
          | :error_occurred
          | :error_recovered
          | :token_usage_updated
          | :turn_completed

  @typedoc """
  An event emitted during session or run execution.

  Matches the structure defined in `AgentSessionManager.Core.Event`.
  """
  @type event :: %{
          required(:type) => event_type(),
          required(:session_id) => session_id(),
          optional(:run_id) => run_id(),
          optional(:data) => map(),
          optional(:timestamp) => DateTime.t(),
          optional(:metadata) => map(),
          optional(:sequence_number) => non_neg_integer()
        }

  @typedoc "Token usage statistics for a run."
  @type token_usage :: %{
          optional(:input_tokens) => non_neg_integer(),
          optional(:output_tokens) => non_neg_integer()
        }

  @typedoc "Result of an agent run execution."
  @type run_result :: %{
          output: term(),
          token_usage: token_usage() | nil,
          turn_count: non_neg_integer(),
          events: [event()]
        }

  # ===========================================================================
  # Callbacks
  # ===========================================================================

  @doc """
  Returns the unique name of this provider.

  Used for logging, metrics, and identifying the provider in
  multi-provider configurations.

  ## Returns

    - A string identifying the provider (e.g., `"claude"`, `"codex"`)
  """
  @callback provider_name() :: String.t()

  @doc """
  Returns the list of capabilities supported by this provider.

  Capabilities define what the agent can do -- tools, resources,
  sampling modes, file access, etc. Consumers use this to verify
  that required capabilities are available before starting sessions.

  ## Returns

    - `{:ok, capabilities}` - List of supported capabilities
    - `{:error, reason}` - If capabilities cannot be determined
  """
  @callback capabilities() :: {:ok, [capability()]} | {:error, term()}

  @doc """
  Starts a new agent session.

  Creates a stateful session with the provider for the given agent
  configuration. The returned session ID is used for subsequent
  `execute/3`, `cancel/2`, and `end_session/1` calls.

  ## Parameters

    - `agent_id` - Identifier for the agent type or configuration
    - `opts` - Session options:
      - `:context` - Shared context data (system prompts, configuration)
      - `:metadata` - Arbitrary metadata for the session
      - `:tags` - List of tags for categorization
      - `:parent_session_id` - Parent session for hierarchical sessions

  ## Returns

    - `{:ok, session_id}` - Session started successfully
    - `{:error, reason}` - Session could not be started
  """
  @callback start_session(agent_id(), opts :: keyword()) ::
              {:ok, session_id()} | {:error, term()}

  @doc """
  Executes a run within an existing session.

  Sends input to the autonomous agent and waits for it to complete
  its tool loop. During execution, the agent may emit events via the
  `:event_callback` option, allowing real-time observation.

  This is the main interaction point. Each call represents one
  "turn" or "run" in the session, but the agent may take multiple
  internal turns (tool calls, reasoning steps) before returning.

  ## Parameters

    - `session_id` - The session to execute within
    - `input` - Input data for the run (prompt, instructions, etc.)
    - `opts` - Execution options:
      - `:event_callback` - `(event() -> any())` called for each event
      - `:timeout` - Maximum execution time in milliseconds
      - `:max_turns` - Maximum number of agent turns

  ## Returns

    - `{:ok, run_result()}` - Run completed successfully
    - `{:error, reason}` - Run failed
  """
  @callback execute(session_id(), input :: map(), opts :: keyword()) ::
              {:ok, run_result()} | {:error, term()}

  @doc """
  Cancels an in-progress run.

  Attempts to gracefully cancel the specified run within the session.
  After cancellation, the run should emit a `:run_cancelled` event.

  ## Parameters

    - `session_id` - The session containing the run
    - `run_id` - The ID of the run to cancel

  ## Returns

    - `{:ok, run_id}` - Cancellation initiated
    - `{:error, reason}` - Cancellation failed
  """
  @callback cancel(session_id(), run_id()) ::
              {:ok, run_id()} | {:error, term()}

  @doc """
  Ends a session and releases associated resources.

  After calling this, the session ID should no longer be used.
  Any in-progress runs should be cancelled.

  ## Parameters

    - `session_id` - The session to end

  ## Returns

    - `:ok` - Session ended successfully
    - `{:error, reason}` - Session could not be ended
  """
  @callback end_session(session_id()) :: :ok | {:error, term()}

  @doc """
  Validates provider-specific configuration.

  Called to ensure all required configuration is present and valid
  before the adapter is used.

  ## Parameters

    - `config` - Configuration map to validate

  ## Returns

    - `:ok` - Configuration is valid
    - `{:error, reason}` - Configuration is invalid
  """
  @callback validate_config(config :: map()) :: :ok | {:error, term()}
end
