defmodule PortfolioCore.Ports.VCSTest do
  use ExUnit.Case, async: true

  alias PortfolioCore.Ports.VCS

  describe "VCS Port Behaviour" do
    test "module exists and compiles without errors" do
      assert Code.ensure_loaded?(PortfolioCore.Ports.VCS)
    end

    test "module is a behaviour" do
      assert function_exported?(VCS, :behaviour_info, 1)
    end

    test "defines required callbacks" do
      callbacks = VCS.behaviour_info(:callbacks)

      # Required callbacks
      assert {:status, 1} in callbacks
      assert {:diff, 3} in callbacks
      assert {:diff_uncommitted, 1} in callbacks
      assert {:stage, 2} in callbacks
      assert {:stage_all, 1} in callbacks
      assert {:unstage, 2} in callbacks
      assert {:commit, 3} in callbacks
      assert {:log, 2} in callbacks
      assert {:show, 2} in callbacks
      assert {:current_branch, 1} in callbacks
      assert {:is_repo?, 1} in callbacks
    end

    test "defines optional callbacks" do
      optional = VCS.behaviour_info(:optional_callbacks)

      # Optional callbacks
      assert {:push, 2} in optional
      assert {:pull, 2} in optional
      assert {:branch_create, 3} in optional
      assert {:branch_delete, 3} in optional
      assert {:checkout, 2} in optional
    end

    test "defines types" do
      # Test that module compiles with typespecs (no runtime type checking needed)
      # The fact that module compiles and dialyzer passes is sufficient verification
      assert Code.ensure_loaded?(VCS)

      # Verify module documentation mentions the key types
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(VCS)
      assert moduledoc =~ "repo()"
      assert moduledoc =~ "commit_hash()"
      assert moduledoc =~ "status()"
      assert moduledoc =~ "diff_result()"
      assert moduledoc =~ "error()"
    end
  end

  describe "Minimal Mock Implementation" do
    defmodule MinimalMock do
      @behaviour PortfolioCore.Ports.VCS

      @impl true
      def status(_repo), do: {:ok, %{}}

      @impl true
      def diff(_repo, _from, _to), do: {:ok, %{patch: "", stats: %{}}}

      @impl true
      def diff_uncommitted(_repo), do: {:ok, %{patch: "", stats: %{}}}

      @impl true
      def stage(_repo, _files), do: :ok

      @impl true
      def stage_all(_repo), do: :ok

      @impl true
      def unstage(_repo, _files), do: :ok

      @impl true
      def commit(_repo, _message, _opts), do: {:ok, "abc123"}

      @impl true
      def log(_repo, _opts), do: {:ok, []}

      @impl true
      def show(_repo, _ref), do: {:ok, %{}}

      @impl true
      def current_branch(_repo), do: {:ok, "main"}

      @impl true
      def is_repo?(_repo), do: true
    end

    test "minimal mock implementation compiles" do
      assert Code.ensure_loaded?(MinimalMock)
    end

    test "minimal mock can be called" do
      assert {:ok, _} = MinimalMock.status("/tmp/repo")
      assert {:ok, _} = MinimalMock.diff("/tmp/repo", "HEAD", "main")
      assert {:ok, _} = MinimalMock.diff_uncommitted("/tmp/repo")
      assert :ok = MinimalMock.stage("/tmp/repo", ["file.txt"])
      assert :ok = MinimalMock.stage_all("/tmp/repo")
      assert :ok = MinimalMock.unstage("/tmp/repo", ["file.txt"])
      assert {:ok, _} = MinimalMock.commit("/tmp/repo", "message", [])
      assert {:ok, _} = MinimalMock.log("/tmp/repo", [])
      assert {:ok, _} = MinimalMock.show("/tmp/repo", "HEAD")
      assert {:ok, _} = MinimalMock.current_branch("/tmp/repo")
      assert true = MinimalMock.is_repo?("/tmp/repo")
    end
  end
end
