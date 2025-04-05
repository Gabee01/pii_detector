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
    # Log the full webhook payload at info level for better debugging
    Logger.info("WEBHOOK: Received Notion webhook payload: #{inspect(params)}")

    if verify_notion_request(conn, params) do
      # Log the entire incoming webhook payload
      Logger.debug("Received Notion webhook: #{inspect(params)}")

      # Process based on webhook type
      case params["type"] do
        # Return early if this is a verification request
        "url_verification" ->
          Logger.info("Received Notion URL verification request")
          json(conn, %{challenge: params["challenge"]})

        # Handle explicit challenge verification
        _ when is_map_key(params, "challenge") ->
          Logger.info("Received Notion URL verification challenge")
          json(conn, %{challenge: params["challenge"]})

        # Queue the event for processing
        event_type when is_binary(event_type) ->
          # Extract a unique ID from the payload to prevent duplicates
          # Use page ID or a timestamp combination if available
          event_id = params["id"] || "#{event_type}_#{System.system_time(:second)}"
          Logger.info("Queueing Notion event: #{event_type} with ID: #{event_id}")

          # Use a well-known existing atom for the unique key
          # which is safe as it doesn't create atoms at runtime

          # Convert string keys to atoms for compatibility
          params
          |> event_worker().new(unique: [period: 60, keys: [:event_type]])
          |> Oban.insert()
          |> handle_job_result(conn)

        # Unknown event type
        nil ->
          Logger.warning("Received Notion webhook with missing event type")
          json(conn, %{status: "ok"})
      end
    else
      Logger.warning("Invalid Notion webhook request")
      send_resp(conn, 401, "Unauthorized")
    end
  end

  # Handle the result of job insertion
  defp handle_job_result(job_result, conn) do
    case job_result do
      {:ok, job} ->
        Logger.info("Successfully inserted Oban job with ID: #{job.id}")
        # Return success
        json(conn, %{status: "ok"})

      {:error, changeset} ->
        Logger.error("Failed to insert Oban job: #{inspect(changeset.errors)}")
        # Return success anyway to prevent Notion from retrying
        # Notion doesn't need to know about our internal job processing
        json(conn, %{status: "ok", message: "Webhook received but job could not be processed"})
    end
  end

  # Verify the incoming Notion request
  defp verify_notion_request(_conn, params) do
    # For now, we just verify if it has expected structure
    # In production, you should implement proper signature verification
    # This is called by the notion controller function

    cond do
      # Check if it's a challenge request
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
