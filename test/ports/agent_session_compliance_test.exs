defmodule PortfolioCore.Ports.AgentSessionComplianceTest do
  use ExUnit.Case, async: true

  defmodule MockAdapter do
    @behaviour PortfolioCore.Ports.AgentSession

    @impl true
    def provider_name, do: "mock"

    @impl true
    def capabilities, do: {:ok, []}

    @impl true
    def start_session(_agent_id, _opts), do: {:ok, "session-123"}

    @impl true
    def execute(_session_id, _input, _opts) do
      {:ok,
       %{
         output: nil,
         token_usage: nil,
         turn_count: 0,
         events: []
       }}
    end

    @impl true
    def cancel(_session_id, _run_id), do: {:ok, "run-123"}

    @impl true
    def end_session(_session_id), do: :ok

    @impl true
    def validate_config(_config), do: :ok
  end

  describe "mock adapter compliance" do
    test "implements provider_name/0" do
      assert MockAdapter.provider_name() == "mock"
    end

    test "implements capabilities/0" do
      assert {:ok, []} = MockAdapter.capabilities()
    end

    test "implements start_session/2" do
      assert {:ok, "session-123"} = MockAdapter.start_session("agent", [])
    end

    test "implements execute/3" do
      assert {:ok, %{output: nil, turn_count: 0}} = MockAdapter.execute("session", %{}, [])
    end

    test "implements cancel/2" do
      assert {:ok, "run-123"} = MockAdapter.cancel("session", "run")
    end

    test "implements end_session/1" do
      assert :ok = MockAdapter.end_session("session")
    end

    test "implements validate_config/1" do
      assert :ok = MockAdapter.validate_config(%{})
    end

    test "mock adapter implements all callbacks without warnings" do
      # If this module compiled, there are no missing callbacks
      assert function_exported?(MockAdapter, :provider_name, 0)
      assert function_exported?(MockAdapter, :capabilities, 0)
      assert function_exported?(MockAdapter, :start_session, 2)
      assert function_exported?(MockAdapter, :execute, 3)
      assert function_exported?(MockAdapter, :cancel, 2)
      assert function_exported?(MockAdapter, :end_session, 1)
      assert function_exported?(MockAdapter, :validate_config, 1)
    end
  end
end
