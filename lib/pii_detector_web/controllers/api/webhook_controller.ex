defmodule PIIDetectorWeb.API.WebhookController do
  use PIIDetectorWeb, :controller

  require Logger

  # def slack(conn, _params) do
  #   # Will implement in next task
  #   conn
  #   |> put_status(200)
  #   |> json(%{status: "ok"})
  # end

  @doc """
  Handle incoming webhook from Notion.
  """
  def notion(conn, params) do
    Logger.info("WEBHOOK: Received Notion webhook payload: #{inspect(params)}")

    if verify_notion_request(conn, params) do
      Logger.debug("Received Notion webhook: #{inspect(params)}")
      handle_verified_notion_webhook(conn, params)
    else
      Logger.warning("Invalid Notion webhook request")
      send_resp(conn, 401, "Unauthorized")
    end
  end

  # Handle verified Notion webhook based on type
  defp handle_verified_notion_webhook(conn, params) do
    case get_webhook_type(params) do
      {:verification, token} ->
        handle_verification_request(conn, token)

      {:event, event_type} ->
        enqueue_notion_event(conn, params, event_type)

      :invalid ->
        handle_invalid_event(conn)
    end
  end

  # Determine the type of webhook received
  defp get_webhook_type(params) do
    cond do
      # Verification request (Step 2 in Notion docs)
      is_map_key(params, "verification_token") ->
        {:verification, params["verification_token"]}

      # URL verification type (keep for backward compatibility)
      params["type"] == "url_verification" and is_map_key(params, "challenge") ->
        {:verification, params["challenge"]}

      # Challenge verification (keeping for backward compatibility)
      is_map_key(params, "challenge") ->
        {:verification, params["challenge"]}

      # Event with a type field (standard format)
      is_binary(params["type"]) ->
        {:event, params["type"]}

      # Invalid or missing type
      true ->
        :invalid
    end
  end

  # Handle verification requests
  defp handle_verification_request(conn, token) do
    Logger.info("Received Notion webhook verification request")
    json(conn, %{challenge: token})
  end

  # Handle events with a valid type
  defp enqueue_notion_event(conn, params, event_type) do
    unique_id = generate_unique_id(params, event_type)
    Logger.info("Queueing Notion event: #{event_type} with ID: #{unique_id}")

    # Add webhook_id to the job for uniqueness tracking
    job_params = Map.put(params, "webhook_id", unique_id)

    job_params
    |> event_worker().new(
      unique: [
        period: 60,
        keys: [:webhook_id]
      ]
    )
    |> Oban.insert()
    |> handle_job_result(conn)
  end

  # Generate a unique ID for the event
  defp generate_unique_id(params, event_type) do
    # Extract entity ID from the Notion webhook structure
    entity_id =
      get_in(params, ["entity", "id"]) ||
        get_in(params, ["page", "id"]) ||
        "no_entity"

    # Use authors if available, or user if available, otherwise no_user
    user_id =
      case get_in(params, ["authors"]) do
        [%{"id" => author_id} | _] when is_binary(author_id) -> author_id
        _ -> get_in(params, ["user", "id"]) || "no_user"
      end

    # Use webhook ID if available to ensure absolute uniqueness
    webhook_id = params["id"] || "#{System.system_time(:second)}"

    # Combine elements to make a truly unique identifier
    "#{event_type}_#{entity_id}_#{user_id}_#{webhook_id}"
  end

  # Handle webhook with missing/invalid event type
  defp handle_invalid_event(conn) do
    Logger.warning("Received Notion webhook with missing event type")
    json(conn, %{status: "ok"})
  end

  # Handle the result of job insertion
  defp handle_job_result(job_result, conn) do
    case job_result do
      {:ok, job} ->
        Logger.info("Successfully inserted Oban job with ID: #{job.id}")
        json(conn, %{status: "ok"})

      {:error, changeset} ->
        Logger.error("Failed to insert Oban job: #{inspect(changeset.errors)}")
        json(conn, %{status: "ok", message: "Webhook received but job could not be processed"})
    end
  end

  # Verify the incoming Notion request
  defp verify_notion_request(_conn, params) do
    # For now, we just verify if it has expected structure
    # In production, you should implement proper signature verification
    # with the X-Notion-Signature header as described in the documentation

    cond do
      # Check if it's a verification request
      Map.has_key?(params, "verification_token") ->
        true

      # Check if it's a legacy verification request
      Map.has_key?(params, "challenge") ->
        true

      # Check if it's a regular event
      Map.has_key?(params, "type") and is_binary(params["type"]) ->
        true

      # Default case
      true ->
        Logger.warning("Invalid Notion webhook structure: #{inspect(params)}")
        false
    end
  end

  # Get the appropriate worker module for the event
  defp event_worker do
    # Return the Notion event worker module
    PIIDetector.Workers.Event.NotionEventWorker
  end
end
