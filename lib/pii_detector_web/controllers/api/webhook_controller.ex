defmodule PIIDetectorWeb.API.WebhookController do
  use PIIDetectorWeb, :controller

  require Logger

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

        # Queue the event for processing
        event_type when is_binary(event_type) ->
          Logger.info("Queueing Notion event: #{event_type}")

          # Convert string keys to atoms for compatibility
          {:ok, _job} = params
          |> event_worker().new()
          |> Oban.insert()

          # Return success
          json(conn, %{status: "success"})

        # Unknown event type
        nil ->
          Logger.warning("Received Notion webhook with missing event type")
          json(conn, %{status: "success"})
      end
    else
      Logger.warning("Invalid Notion webhook request")
      send_resp(conn, 401, "Unauthorized")
    end
  end

  # Handle the verification token case (for backward compatibility)
  defp handle_notion_verification_token(conn, %{"verification_token" => token}) do
    Logger.info("Handling Notion webhook verification token: #{token}")

    conn
    |> put_status(200)
    |> json(%{status: "ok"})
  end

  # Handle the challenge case (this is what Notion currently uses)
  defp handle_notion_challenge(conn, %{"challenge" => challenge}) do
    # Respond with the challenge value to verify webhook setup
    Logger.info("Handling Notion webhook verification challenge: #{challenge}")

    conn
    |> put_status(200)
    |> json(%{challenge: challenge})
  end

  defp verify_notion_webhook_signature(conn) do
    # Log headers to check for Notion signature header
    Logger.debug("Signature verification headers: #{inspect(conn.req_headers)}")

    # In a real implementation, this would verify the webhook signature
    # using the signing secret from the configuration and the x-notion-signature header

    # Example verification logic (to be implemented):
    # signature_header = get_req_header(conn, "x-notion-signature")
    # if signature_header and verify_signature(conn.body_params, signature_header, webhook_secret) do
    #   :ok
    # else
    #   {:error, "Invalid signature"}
    # end

    # For now, we'll skip validation in this implementation
    # and just return :ok to accept all webhooks
    # In a production environment, you would want to properly verify the signature

    # TODO: Implement proper signature verification for production
    :ok
  end

  # Verify the incoming Notion request
  defp verify_notion_request(conn, params) do
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
