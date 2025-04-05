defmodule PIIDetector.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use PIIDetector.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias PIIDetector.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import PIIDetector.DataCase

      # Include Oban.Testing in all tests using DataCase
      use Oban.Testing, repo: PIIDetector.Repo
    end
  end

  setup tags do
    PIIDetector.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(PIIDetector.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  Sets up mocks for a test module.

  This function ensures proper isolation between tests when using mocks.
  It should be called in a setup block in any test module using mocks.

  ## Example

      setup :setup_mocks
  """
  def setup_mocks(_context) do
    # Set up mocks for isolated test
    if Process.whereis(Mox.Server) do
      Mox.verify_on_exit!()

      # By default, use private mode for better test isolation
      # Individual tests can override this by calling Mox.set_mox_global()
      # in their own setup blocks if needed
      Mox.set_mox_private()
    end

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
