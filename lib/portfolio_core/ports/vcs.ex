defmodule PortfolioCore.Ports.VCS do
  @moduledoc """
  Port behaviour for version control system operations.

  This behaviour defines the contract for VCS adapters, enabling support for
  multiple version control systems (Git, Mercurial, SVN, etc.) through a
  common interface.

  ## Type Specifications

  The following types are used throughout the VCS port:

  - `repo()` - Path to the repository root directory
  - `commit_hash()` - Full commit SHA identifier
  - `ref()` - Git reference (branch name, tag, or SHA)
  - `file_path()` - Path to a file relative to repository root
  - `status()` - Complete repository status information
  - `diff_result()` - Diff patch with statistics
  - `commit()` - Complete commit information
  - `error()` - Tagged tuples for all failure modes

  ## Required Callbacks

  All VCS adapters must implement:

  - `status/1` - Get repository status (dirty state, branches, tracking)
  - `diff/3` - Diff between two refs
  - `diff_uncommitted/1` - Diff uncommitted changes
  - `stage/2` - Stage specific files
  - `stage_all/1` - Stage all changes
  - `unstage/2` - Unstage files
  - `commit/3` - Create commit with message and options
  - `log/2` - Get commit history
  - `show/2` - Show commit details
  - `current_branch/1` - Get current branch name
  - `is_repo?/1` - Check if path is a repository

  ## Optional Callbacks

  Adapters may optionally implement:

  - `push/2` - Push to remote
  - `pull/2` - Pull from remote
  - `branch_create/3` - Create a new branch
  - `branch_delete/3` - Delete a branch
  - `checkout/2` - Checkout a ref

  ## Usage Example

      defmodule MyApp.Git do
        @behaviour PortfolioCore.Ports.VCS

        @impl true
        def status(repo) do
          # Implementation
        end

        # ... other callbacks
      end

      # Using the adapter
      {:ok, status} = MyApp.Git.status("/path/to/repo")
      if status.is_dirty do
        {:ok, _} = MyApp.Git.stage_all("/path/to/repo")
        {:ok, hash} = MyApp.Git.commit("/path/to/repo", "Fix bug", [])
      end
  """

  @typedoc "Path to repository root directory"
  @type repo :: Path.t()

  @typedoc "Full commit SHA identifier"
  @type commit_hash :: String.t()

  @typedoc "Git reference (branch name, tag, or SHA)"
  @type ref :: String.t()

  @typedoc "Path to a file relative to repository root"
  @type file_path :: String.t()

  @typedoc """
  Complete repository status information.

  ## Fields

  - `changed_files` - Modified files in working directory
  - `staged_files` - Files staged for commit
  - `untracked_files` - New files not tracked by VCS
  - `deleted_files` - Files deleted from working directory
  - `is_dirty` - Whether repository has uncommitted changes
  - `current_branch` - Name of current branch (nil if detached HEAD)
  - `upstream_branch` - Name of tracked remote branch
  - `ahead_count` - Number of commits ahead of upstream
  - `behind_count` - Number of commits behind upstream
  """
  @type status :: %{
          changed_files: [file_path()],
          staged_files: [file_path()],
          untracked_files: [file_path()],
          deleted_files: [file_path()],
          is_dirty: boolean(),
          current_branch: String.t() | nil,
          upstream_branch: String.t() | nil,
          ahead_count: non_neg_integer(),
          behind_count: non_neg_integer()
        }

  @typedoc """
  Diff result containing patch text and statistics.

  ## Fields

  - `patch` - Unified diff patch text
  - `stats` - Statistics about the changes
  """
  @type diff_result :: %{
          patch: String.t(),
          stats: diff_stats()
        }

  @typedoc """
  Statistics about diff changes.

  ## Fields

  - `additions` - Total lines added
  - `deletions` - Total lines deleted
  - `files_changed` - Number of files changed
  - `files` - Per-file statistics
  """
  @type diff_stats :: %{
          additions: non_neg_integer(),
          deletions: non_neg_integer(),
          files_changed: non_neg_integer(),
          files: [
            %{
              path: file_path(),
              additions: non_neg_integer(),
              deletions: non_neg_integer()
            }
          ]
        }

  @typedoc """
  Complete commit information.

  ## Fields

  - `hash` - Full commit SHA
  - `short_hash` - Abbreviated commit SHA (7-10 chars)
  - `author` - Commit author name
  - `author_email` - Commit author email
  - `message` - Full commit message
  - `subject` - First line of commit message
  - `timestamp` - Commit timestamp
  - `parents` - Parent commit SHAs
  """
  @type commit :: %{
          hash: commit_hash(),
          short_hash: String.t(),
          author: String.t(),
          author_email: String.t(),
          message: String.t(),
          subject: String.t(),
          timestamp: DateTime.t(),
          parents: [commit_hash()]
        }

  @typedoc """
  VCS operation errors.

  ## Error Types

  - `{:repository_not_found, repo}` - Path is not a VCS repository
  - `{:invalid_ref, ref}` - Reference does not exist
  - `{:merge_conflict, files}` - Merge conflict in specified files
  - `{:permission_denied, message}` - Permission error
  - `{:command_failed, code, output}` - VCS command failed
  - `{:uncommitted_changes, files}` - Uncommitted changes prevent operation
  - `{:diverged_branches, ahead, behind}` - Branches have diverged
  - `:nothing_to_commit` - No changes to commit
  """
  @type error ::
          {:repository_not_found, repo()}
          | {:invalid_ref, ref()}
          | {:merge_conflict, [file_path()]}
          | {:permission_denied, String.t()}
          | {:command_failed, exit_code :: integer(), output :: String.t()}
          | {:uncommitted_changes, [file_path()]}
          | {:diverged_branches, ahead :: non_neg_integer(), behind :: non_neg_integer()}
          | :nothing_to_commit

  @doc """
  Get the current status of the repository.

  Returns status information including changed files, staged files, untracked
  files, branch information, and tracking status.

  ## Examples

      {:ok, status} = adapter.status("/path/to/repo")
      if status.is_dirty do
        IO.puts("Repository has uncommitted changes")
      end
  """
  @callback status(repo()) :: {:ok, status()} | {:error, error()}

  @doc """
  Get the diff between two refs.

  Returns a unified diff patch and statistics about the changes.

  ## Examples

      {:ok, result} = adapter.diff("/path/to/repo", "main", "feature")
      IO.puts("Changed \#{result.stats.files_changed} files")
  """
  @callback diff(repo(), from :: ref(), to :: ref()) ::
              {:ok, diff_result()} | {:error, error()}

  @doc """
  Get the diff of uncommitted changes.

  Returns a unified diff patch and statistics for all uncommitted changes
  in the working directory.

  ## Examples

      {:ok, result} = adapter.diff_uncommitted("/path/to/repo")
      IO.puts(result.patch)
  """
  @callback diff_uncommitted(repo()) :: {:ok, diff_result()} | {:error, error()}

  @doc """
  Stage specific files for commit.

  ## Examples

      :ok = adapter.stage("/path/to/repo", ["file1.txt", "file2.txt"])
  """
  @callback stage(repo(), [file_path()]) :: :ok | {:error, error()}

  @doc """
  Stage all changes for commit.

  Stages all modified, deleted, and new files.

  ## Examples

      :ok = adapter.stage_all("/path/to/repo")
  """
  @callback stage_all(repo()) :: :ok | {:error, error()}

  @doc """
  Unstage files (remove from staging area).

  ## Examples

      :ok = adapter.unstage("/path/to/repo", ["file1.txt"])
  """
  @callback unstage(repo(), [file_path()]) :: :ok | {:error, error()}

  @doc """
  Create a commit with the given message.

  ## Options

  - `:allow_empty` - Allow creating an empty commit (default: false)
  - `:amend` - Amend the previous commit (default: false)
  - `:no_verify` - Skip pre-commit hooks (default: false)

  ## Examples

      {:ok, hash} = adapter.commit("/path/to/repo", "Fix bug in parser", [])
      {:ok, hash} = adapter.commit("/path/to/repo", "Empty commit", allow_empty: true)
  """
  @callback commit(repo(), message :: String.t(), opts :: keyword()) ::
              {:ok, commit_hash()} | {:error, error()}

  @doc """
  Get commit history.

  ## Options

  - `:limit` - Maximum number of commits to return (default: unlimited)
  - `:skip` - Number of commits to skip (default: 0)

  ## Examples

      {:ok, commits} = adapter.log("/path/to/repo", limit: 10)
      Enum.each(commits, fn c -> IO.puts("\#{c.short_hash} \#{c.subject}") end)
  """
  @callback log(repo(), opts :: keyword()) :: {:ok, [commit()]} | {:error, error()}

  @doc """
  Show details for a specific commit.

  ## Examples

      {:ok, commit} = adapter.show("/path/to/repo", "abc123")
      IO.puts("Author: \#{commit.author}")
  """
  @callback show(repo(), ref()) :: {:ok, commit()} | {:error, error()}

  @doc """
  Get the name of the current branch.

  Returns `{:ok, nil}` if in detached HEAD state.

  ## Examples

      {:ok, branch} = adapter.current_branch("/path/to/repo")
      IO.puts("On branch: \#{branch}")
  """
  @callback current_branch(repo()) :: {:ok, String.t() | nil} | {:error, error()}

  @doc """
  Check if the given path is a VCS repository.

  ## Examples

      if adapter.is_repo?("/path/to/repo") do
        IO.puts("Valid repository")
      end
  """
  @callback is_repo?(repo()) :: boolean()

  @doc """
  Push commits to remote repository.

  ## Options

  - `:remote` - Remote name (default: "origin")
  - `:branch` - Branch to push (default: current branch)
  - `:force` - Force push (requires approval gate)
  - `:set_upstream` - Set upstream tracking

  ## Examples

      :ok = adapter.push("/path/to/repo", remote: "origin", branch: "main")
  """
  @callback push(repo(), opts :: keyword()) :: :ok | {:error, error()}

  @doc """
  Pull commits from remote repository.

  ## Options

  - `:remote` - Remote name (default: "origin")
  - `:branch` - Branch to pull (default: current branch)
  - `:rebase` - Use rebase instead of merge

  ## Examples

      :ok = adapter.pull("/path/to/repo", rebase: true)
  """
  @callback pull(repo(), opts :: keyword()) :: :ok | {:error, error()}

  @doc """
  Create a new branch.

  ## Options

  - `:from` - Starting ref for new branch (default: HEAD)
  - `:checkout` - Checkout the branch after creating (default: false)

  ## Examples

      :ok = adapter.branch_create("/path/to/repo", "feature", from: "main")
  """
  @callback branch_create(repo(), name :: String.t(), opts :: keyword()) ::
              :ok | {:error, error()}

  @doc """
  Delete a branch.

  ## Options

  - `:force` - Force delete unmerged branch (requires approval gate)
  - `:remote` - Delete remote branch instead of local

  ## Examples

      :ok = adapter.branch_delete("/path/to/repo", "old-feature", [])
  """
  @callback branch_delete(repo(), name :: String.t(), opts :: keyword()) ::
              :ok | {:error, error()}

  @doc """
  Checkout a ref (branch, tag, or commit).

  ## Examples

      :ok = adapter.checkout("/path/to/repo", "feature-branch")
  """
  @callback checkout(repo(), ref()) :: :ok | {:error, error()}

  @optional_callbacks [
    push: 2,
    pull: 2,
    branch_create: 3,
    branch_delete: 3,
    checkout: 2
  ]
end
