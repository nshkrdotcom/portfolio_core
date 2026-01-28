defmodule PortfolioCore.Ports.LLM do
  @moduledoc """
  Port specification for Large Language Model backends.

  Provides text generation and completion capabilities using various
  LLM providers (OpenAI, Anthropic, Google, local models).

  ## Features

  - Chat completions with message history
  - Streaming support
  - Token usage tracking
  - Model information

  ## Example Implementation

      defmodule MyApp.Adapters.AnthropicLLM do
        @behaviour PortfolioCore.Ports.LLM

        @impl true
        def complete(messages, opts) do
          model = Keyword.get(opts, :model, "claude-3-sonnet-20240229")
          # Call Anthropic API
        end
      end

  ## Message Format

  Messages follow a standard format with roles and content:

      [
        %{role: :system, content: "You are a helpful assistant."},
        %{role: :user, content: "What is Elixir?"},
        %{role: :assistant, content: "Elixir is a functional language..."}
      ]
  """

  @type message :: %{role: :system | :user | :assistant, content: String.t()}
  @type model :: String.t()

  @type completion_result :: %{
          content: String.t(),
          model: model(),
          usage: %{
            input_tokens: non_neg_integer(),
            output_tokens: non_neg_integer()
          },
          finish_reason: :stop | :length | :tool_use,
          response_id: String.t() | nil
        }

  @type stream_chunk :: %{
          delta: String.t(),
          finish_reason: :stop | :length | nil
        }

  @doc """
  Generate a completion for the given messages.

  ## Parameters

    - `messages` - List of messages in the conversation
    - `opts` - Completion options:
      - `:model` - Model to use
      - `:max_tokens` - Maximum tokens to generate (legacy for chat completions)
      - `:max_completion_tokens` - Maximum completion tokens (newer chat models)
      - `:max_output_tokens` - Maximum output tokens (Responses API)
      - `:temperature` - Sampling temperature (0.0 - 2.0)
      - `:stop` - Stop sequences
      - `:api` - `:chat_completions` or `:responses`
      - `:store` - Whether the provider should store state
      - `:previous_response_id` - Chain to a previous response when supported

  ## Returns

    - `{:ok, result}` with completion and usage info
    - `{:error, reason}` on failure
  """
  @callback complete([message()], opts :: keyword()) ::
              {:ok, completion_result()} | {:error, term()}

  @doc """
  Stream a completion for the given messages.

  Returns an enumerable that yields chunks as they arrive.

  ## Parameters

    - `messages` - List of messages in the conversation
    - `opts` - Completion options (same as complete/2)

  ## Returns

    - `{:ok, stream}` - Enumerable of stream chunks
    - `{:error, reason}` on failure
  """
  @callback stream([message()], opts :: keyword()) ::
              {:ok, Enumerable.t()} | {:error, term()}

  @doc """
  Get list of supported models.

  ## Returns

    - List of model identifiers supported by this adapter
  """
  @callback supported_models() :: [model()]

  @doc """
  Get information about a specific model.

  ## Parameters

    - `model` - The model identifier

  ## Returns

    - Map with model capabilities and limits
  """
  @callback model_info(model()) :: %{
              context_window: pos_integer(),
              max_output: pos_integer(),
              supports_tools: boolean()
            }
end
