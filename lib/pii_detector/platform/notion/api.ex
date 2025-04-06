defmodule PIIDetector.Platform.Notion.API do
  @moduledoc """
  Implementation of Notion API client.
  """
  @behaviour PIIDetector.Platform.Notion.APIBehaviour

  require Logger

  @default_base_url "https://api.notion.com/v1"
  @default_notion_version "2022-06-28"

  @impl true
  def get_page(page_id, token \\ nil, opts \\ []) do
    with {:ok, token} <- ensure_token(token),
         {:ok, url, headers} <- prepare_request("/pages/#{page_id}", token, opts) do
      Logger.debug("Making Notion API request to #{url}")

      case Req.get(url, [headers: headers] ++ request_options(opts)) do
        {:ok, %{status: 200, body: body}} ->
          Logger.info("Successfully fetched Notion page: #{page_id}")
          {:ok, body}

        {:ok, %{status: 401, body: body}} ->
          Logger.error("Authentication error fetching Notion page: #{inspect(body)}")
          {:error, "Authentication failed - invalid API token"}

        {:ok, %{status: 404, body: body}} ->
          Logger.error(
            "Page not found or integration lacks access to page: #{page_id}, response: #{inspect(body)}"
          )

          {:error,
           "Page not found or integration lacks access - verify integration is added to page"}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Error fetching Notion page: status=#{status}, body=#{inspect(body)}")
          {:error, "API error: #{status}"}

        {:error, reason} ->
          Logger.error("Failed to connect to Notion API: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @impl true
  def get_blocks(page_id, token \\ nil, opts \\ []) do
    with {:ok, token} <- ensure_token(token),
         {:ok, url, headers} <- prepare_request("/blocks/#{page_id}/children", token, opts) do
      Logger.debug("Making Notion API request to #{url}")

      case Req.get(url, [headers: headers] ++ request_options(opts)) do
        {:ok, %{status: 200, body: %{"results" => results}}} ->
          Logger.info("Successfully fetched blocks for Notion page: #{page_id}")
          {:ok, results}

        {:ok, %{status: 401, body: body}} ->
          Logger.error("Authentication error fetching Notion blocks: #{inspect(body)}")
          {:error, "Authentication failed - invalid API token"}

        {:ok, %{status: 404, body: body}} ->
          Logger.error(
            "Page not found or integration lacks access to blocks: #{page_id}, response: #{inspect(body)}"
          )

          {:ok,
           "Page not found or integration lacks access - verify integration is added to page"}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Error fetching Notion blocks: status=#{status}, body=#{inspect(body)}")
          {:error, "API error: #{status}"}

        {:error, reason} ->
          Logger.error("Failed to connect to Notion API: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @impl true
  def get_database_entries(database_id, token \\ nil, opts \\ []) do
    with {:ok, token} <- ensure_token(token),
         {:ok, url, headers} <- prepare_request("/databases/#{database_id}/query", token, opts) do
      Logger.debug("Making Notion API request to #{url}")

      case Req.post(url, [headers: headers, json: %{}] ++ request_options(opts)) do
        {:ok, %{status: 200, body: %{"results" => results}}} ->
          Logger.info("Successfully fetched database entries for Notion database: #{database_id}")
          {:ok, results}

        {:ok, %{status: 401, body: body}} ->
          Logger.error("Authentication error fetching Notion database entries: #{inspect(body)}")
          {:error, "Authentication failed - invalid API token"}

        {:ok, %{status: status, body: body}} ->
          Logger.error(
            "Error fetching Notion database entries: status=#{status}, body=#{inspect(body)}"
          )

          {:error, "API error: #{status}"}

        {:error, reason} ->
          Logger.error("Failed to connect to Notion API: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @impl true
  def archive_page(page_id, token \\ nil, opts \\ []) do
    with {:ok, token} <- ensure_token(token),
         {:ok, url, headers} <- prepare_request("/pages/#{page_id}", token, opts) do
      payload = %{
        "archived" => true
      }

      Logger.debug("Making Notion API request to #{url}")

      case Req.patch(url, [headers: headers, json: payload] ++ request_options(opts)) do
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
    end
  end

  @impl true
  def archive_database_entry(page_id, token \\ nil, opts \\ []) do
    # Database entries in Notion are just pages, so we can reuse the archive_page function
    archive_page(page_id, token, opts)
  end

  @impl true
  def get_user(user_id, token \\ nil, opts \\ []) do
    with {:ok, token} <- ensure_token(token),
         {:ok, url, headers} <- prepare_request("/users/#{user_id}", token, opts) do
      Logger.debug("Making Notion API request to get user: #{user_id}")

      case Req.get(url, [headers: headers] ++ request_options(opts)) do
        {:ok, %{status: 200, body: body}} ->
          Logger.info("Successfully fetched Notion user: #{user_id}")
          {:ok, body}

        {:ok, %{status: 401, body: body}} ->
          Logger.error("Authentication error fetching Notion user: #{inspect(body)}")
          {:error, "Authentication failed - invalid API token"}

        {:ok, %{status: 404, body: body}} ->
          Logger.error(
            "User not found or integration lacks access: #{user_id}, response: #{inspect(body)}"
          )

          {:error, "User not found or integration lacks access"}

        {:ok, %{status: status, body: body}} ->
          Logger.error("Error fetching Notion user: status=#{status}, body=#{inspect(body)}")
          {:error, "API error: #{status}"}

        {:error, reason} ->
          Logger.error("Failed to connect to Notion API: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  # Private helper functions

  defp ensure_token(nil) do
    case get_api_key_from_config() do
      nil ->
        Logger.error("No Notion API key available")
        {:error, "Missing API token"}

      token ->
        {:ok, token}
    end
  end

  defp ensure_token(token) when is_binary(token), do: {:ok, token}

  defp prepare_request(path, token, opts) do
    base_url = Keyword.get(opts, :base_url) || get_base_url_from_config()
    notion_version = Keyword.get(opts, :notion_version) || get_notion_version_from_config()

    url = base_url <> path

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Notion-Version", notion_version},
      {"Content-Type", "application/json"}
    ]

    {:ok, url, headers}
  end

  defp request_options(opts) do
    default_opts = Application.get_env(:pii_detector, :req_options, [])
    Keyword.merge(default_opts, Keyword.drop(opts, [:base_url, :notion_version]))
  end

  defp get_api_key_from_config do
    Application.get_env(:pii_detector, PIIDetector.Platform.Notion)[:api_key] ||
      System.get_env("NOTION_API_KEY")
  end

  defp get_base_url_from_config do
    Application.get_env(:pii_detector, PIIDetector.Platform.Notion)[:base_url] ||
      @default_base_url
  end

  defp get_notion_version_from_config do
    Application.get_env(:pii_detector, PIIDetector.Platform.Notion)[:notion_version] ||
      @default_notion_version
  end
end
