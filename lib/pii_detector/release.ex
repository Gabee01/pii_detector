defmodule PIIDetector.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :pii_detector

  require Logger

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def verify_runtime_config do
    load_app()

    # Check for critical environment variables
    check_env_var("NOTION_API_TOKEN", "No Notion API token found. Set NOTION_API_TOKEN or NOTION_API_KEY environment variable.")

    # Additional checks can be added here
    :ok
  end

  defp check_env_var(name, error_message) do
    case System.get_env(name) do
      nil ->
        if name == "NOTION_API_TOKEN" && System.get_env("NOTION_API_KEY") do
          # Special case for Notion API which can use either name
          :ok
        else
          Logger.warning(error_message)
        end
      _ -> :ok
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
