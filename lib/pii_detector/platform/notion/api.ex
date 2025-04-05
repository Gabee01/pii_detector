defmodule PIIDetector.Platform.Notion.API do
  @moduledoc """
  Implementation of Notion API client.
  """
  @behaviour PIIDetector.Platform.Notion.APIBehaviour

  require Logger

  @impl true
  def get_page(page_id, token \\ nil, opts \\ []) do
    token = token || config()[:api_token]
    url = "#{config()[:base_url]}/pages/#{page_id}"

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Notion-Version", config()[:notion_version]},
      {"Content-Type", "application/json"}
    ]

    # Merge default options with any provided options
    req_options = Keyword.merge(req_options(), opts)
    Logger.debug("Making Notion API request to #{url} with options: #{inspect(req_options)}")

    case Req.get(url, [headers: headers] ++ req_options) do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("Successfully fetched Notion page: #{page_id}")
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Error fetching Notion page: status=#{status}, body=#{inspect(body)}")
        {:error, "API error: #{status}"}

      {:error, reason} ->
        Logger.error("Failed to connect to Notion API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def get_blocks(page_id, token \\ nil, opts \\ []) do
    token = token || config()[:api_token]
    url = "#{config()[:base_url]}/blocks/#{page_id}/children"

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Notion-Version", config()[:notion_version]},
      {"Content-Type", "application/json"}
    ]

    # Merge default options with any provided options
    req_options = Keyword.merge(req_options(), opts)
    Logger.debug("Making Notion API request to #{url} with options: #{inspect(req_options)}")

    case Req.get(url, [headers: headers] ++ req_options) do
      {:ok, %{status: 200, body: %{"results" => results}}} ->
        Logger.info("Successfully fetched blocks for Notion page: #{page_id}")
        {:ok, results}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Error fetching Notion blocks: status=#{status}, body=#{inspect(body)}")
        {:error, "API error: #{status}"}

      {:error, reason} ->
        Logger.error("Failed to connect to Notion API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def get_database_entries(database_id, token \\ nil, opts \\ []) do
    token = token || config()[:api_token]
    url = "#{config()[:base_url]}/databases/#{database_id}/query"

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Notion-Version", config()[:notion_version]},
      {"Content-Type", "application/json"}
    ]

    # Merge default options with any provided options
    req_options = Keyword.merge(req_options(), opts)
    Logger.debug("Making Notion API request to #{url} with options: #{inspect(req_options)}")

    case Req.post(url, [headers: headers, json: %{}] ++ req_options) do
      {:ok, %{status: 200, body: %{"results" => results}}} ->
        Logger.info("Successfully fetched database entries for Notion database: #{database_id}")
        {:ok, results}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Error fetching Notion database entries: status=#{status}, body=#{inspect(body)}")
        {:error, "API error: #{status}"}

      {:error, reason} ->
        Logger.error("Failed to connect to Notion API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def archive_page(page_id, token \\ nil, opts \\ []) do
    token = token || config()[:api_token]
    url = "#{config()[:base_url]}/pages/#{page_id}"

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Notion-Version", config()[:notion_version]},
      {"Content-Type", "application/json"}
    ]

    payload = %{
      "archived" => true
    }

    # Merge default options with any provided options
    req_options = Keyword.merge(req_options(), opts)
    Logger.debug("Making Notion API request to #{url} with options: #{inspect(req_options)}")

    case Req.patch(url, [headers: headers, json: payload] ++ req_options) do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("Successfully archived Notion page: #{page_id}")
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Error archiving Notion page: status=#{status}, body=#{inspect(body)}")
        {:error, "API error: #{status}"}

      {:error, reason} ->
        Logger.error("Failed to connect to Notion API: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def archive_database_entry(page_id, token \\ nil, opts \\ []) do
    # Database entries in Notion are just pages, so we can reuse the archive_page function
    archive_page(page_id, token, opts)
  end

  defp config do
    Application.get_env(:pii_detector, PIIDetector.Platform.Notion)
  end

  defp req_options do
    Application.get_env(:pii_detector, :req_options, [])
  end
end
