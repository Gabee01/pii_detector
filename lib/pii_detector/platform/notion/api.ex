defmodule PIIDetector.Platform.Notion.API do
  @moduledoc """
  Implementation of Notion API client.
  """
  @behaviour PIIDetector.Platform.Notion.APIBehaviour

  require Logger

  @impl true
  def get_page(page_id, token \\ nil, opts \\ []) do
    token = token || config()[:api_token]

    if token do
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

        {:ok, %{status: 401, body: body}} ->
          Logger.error("Authentication error fetching Notion page: #{inspect(body)}")
          {:error, "Authentication failed - invalid API token"}

        {:ok, %{status: 404, body: body}} ->
          Logger.error("Page not found or integration lacks access to page: #{page_id}, response: #{inspect(body)}")
          {:error, "Page not found or integration lacks access - verify integration is added to page"}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Error fetching Notion page: status=#{status}, body=#{inspect(body)}")
          {:error, "API error: #{status}"}

        {:error, reason} ->
          Logger.error("Failed to connect to Notion API: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.error("No Notion API token available - cannot fetch page: #{page_id}")
      {:error, "Missing API token"}
    end
  end

  @impl true
  def get_blocks(page_id, token \\ nil, opts \\ []) do
    token = token || config()[:api_token]

    if token do
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

        {:ok, %{status: 401, body: body}} ->
          Logger.error("Authentication error fetching Notion blocks: #{inspect(body)}")
          {:error, "Authentication failed - invalid API token"}

        {:ok, %{status: 404, body: body}} ->
          Logger.error("Page not found or integration lacks access to blocks: #{page_id}, response: #{inspect(body)}")
          {:error, "Page not found or integration lacks access - verify integration is added to page"}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Error fetching Notion blocks: status=#{status}, body=#{inspect(body)}")
          {:error, "API error: #{status}"}

        {:error, reason} ->
          Logger.error("Failed to connect to Notion API: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.error("No Notion API token available - cannot fetch blocks: #{page_id}")
      {:error, "Missing API token"}
    end
  end

  @impl true
  def get_database_entries(database_id, token \\ nil, opts \\ []) do
    token = token || config()[:api_token]

    if token do
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

        {:ok, %{status: 401, body: body}} ->
          Logger.error("Authentication error fetching Notion database entries: #{inspect(body)}")
          {:error, "Authentication failed - invalid API token"}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Error fetching Notion database entries: status=#{status}, body=#{inspect(body)}")
          {:error, "API error: #{status}"}

        {:error, reason} ->
          Logger.error("Failed to connect to Notion API: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.error("No Notion API token available - cannot fetch database entries: #{database_id}")
      {:error, "Missing API token"}
    end
  end

  @impl true
  def archive_page(page_id, token \\ nil, opts \\ []) do
    token = token || config()[:api_token]

    if token do
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

        {:ok, %{status: 401, body: body}} ->
          Logger.error("Authentication error archiving Notion page: #{inspect(body)}")
          {:error, "Authentication failed - invalid API token"}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Error archiving Notion page: status=#{status}, body=#{inspect(body)}")
          {:error, "API error: #{status}"}

        {:error, reason} ->
          Logger.error("Failed to connect to Notion API: #{inspect(reason)}")
          {:error, reason}
      end
    else
      Logger.error("No Notion API token available - cannot archive page: #{page_id}")
      {:error, "Missing API token"}
    end
  end

  @impl true
  def archive_database_entry(page_id, token \\ nil, opts \\ []) do
    # Database entries in Notion are just pages, so we can reuse the archive_page function
    archive_page(page_id, token, opts)
  end

  defp config do
    config = Application.get_env(:pii_detector, PIIDetector.Platform.Notion, %{})

    # Convert to map if it's a keyword list
    config = if is_list(config), do: Map.new(config), else: config

    # Try to get token from both possible environment variables if it's missing in config
    api_token = Map.get(config, :api_token) ||
                System.get_env("NOTION_API_TOKEN") ||
                System.get_env("NOTION_API_KEY")

    if api_token do
      token_preview = String.slice(api_token, 0, 4) <> "..." <> String.slice(api_token, -4, 4)
      Logger.debug("Using Notion API token: #{token_preview}")
      Map.put(config, :api_token, api_token)
    else
      Logger.error("Notion API token not found! Check environment variables NOTION_API_TOKEN or NOTION_API_KEY")
      Map.put(config, :api_token, nil)
    end
  end

  defp req_options do
    Application.get_env(:pii_detector, :req_options, [])
  end
end
