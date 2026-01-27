defmodule PortfolioCore.Ports.AgentSessionTest do
  use ExUnit.Case, async: true

  alias PortfolioCore.Ports.AgentSession

  describe "behaviour definition" do
    test "module exists and is a behaviour" do
      assert Code.ensure_loaded?(AgentSession)
      callbacks = AgentSession.behaviour_info(:callbacks)
      assert is_list(callbacks)
    end

    test "defines provider_name/0 callback" do
      callbacks = AgentSession.behaviour_info(:callbacks)
      assert {:provider_name, 0} in callbacks
    end

    test "defines capabilities/0 callback" do
      callbacks = AgentSession.behaviour_info(:callbacks)
      assert {:capabilities, 0} in callbacks
    end

    test "defines start_session/2 callback" do
      callbacks = AgentSession.behaviour_info(:callbacks)
      assert {:start_session, 2} in callbacks
    end

    test "defines execute/3 callback" do
      callbacks = AgentSession.behaviour_info(:callbacks)
      assert {:execute, 3} in callbacks
    end

    test "defines cancel/2 callback" do
      callbacks = AgentSession.behaviour_info(:callbacks)
      assert {:cancel, 2} in callbacks
    end

    test "defines end_session/1 callback" do
      callbacks = AgentSession.behaviour_info(:callbacks)
      assert {:end_session, 1} in callbacks
    end

    test "defines validate_config/1 callback" do
      callbacks = AgentSession.behaviour_info(:callbacks)
      assert {:validate_config, 1} in callbacks
    end
  end

  describe "typespecs" do
    test "exports type specifications" do
      assert {:ok, types} = Code.Typespec.fetch_types(AgentSession)
      assert is_list(types)
      assert types != []

      type_names = Enum.map(types, fn {_kind, {name, _, _}} -> name end)

      assert :session_id in type_names
      assert :run_id in type_names
      assert :agent_id in type_names
      assert :session_status in type_names
      assert :run_status in type_names
      assert :capability_type in type_names
      assert :capability in type_names
      assert :event_type in type_names
      assert :event in type_names
      assert :token_usage in type_names
      assert :run_result in type_names
    end
  end

  describe "documentation" do
    test "has moduledoc" do
      assert {:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(AgentSession)

      doc =
        case moduledoc do
          %{"en" => text} -> text
          {"en", text} -> text
          _ -> nil
        end

      assert is_binary(doc)
      assert String.length(doc) > 0
    end

    test "moduledoc mentions distinction from LLM and Agent ports" do
      {:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(AgentSession)

      doc =
        case moduledoc do
          %{"en" => text} -> text
          {"en", text} -> text
        end

      assert doc =~ "LLM"
      assert doc =~ "Agent"
    end
  end
end
