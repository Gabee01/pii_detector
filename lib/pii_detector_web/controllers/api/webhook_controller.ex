defmodule PIIDetectorWeb.API.WebhookController do
  use PIIDetectorWeb, :controller

  require Logger

  def slack(conn, _params) do
    # Will implement in next task
    conn
    |> put_status(200)
    |> json(%{status: "ok"})
  end

  def notion(conn, params) do
    # Handle verification challenge if present
    if Map.has_key?(params, "challenge") do
      handle_notion_verification(conn, params)
    else
      # Verify webhook signature
      case verify_notion_webhook_signature(conn) do
        :ok ->
          # Parse event data and enqueue for processing
          {:ok, _job} = Oban.insert(PIIDetector.Workers.Event.NotionEventWorker.new(params))

          Logger.info("Received and queued Notion webhook event",
            event_type: params["type"]
          )

          # Respond to Notion with success
          conn
          |> put_status(200)
          |> json(%{status: "ok"})

        {:error, reason} ->
          # Log invalid signature attempt
          Logger.warning("Invalid Notion webhook signature: #{reason}")

          # Return 401 Unauthorized
          conn
          |> put_status(401)
          |> json(%{status: "error", message: "Invalid signature"})
      end
    end
  end

  defp handle_notion_verification(conn, %{"challenge" => challenge}) do
    # Respond with the challenge value to verify webhook setup
    Logger.info("Handling Notion webhook verification challenge")

    conn
    |> put_status(200)
    |> json(%{challenge: challenge})
  end

  defp verify_notion_webhook_signature(_conn) do
    # In a real implementation, this would verify the webhook signature
    # using the signing secret from the configuration

    # For now, we'll skip validation in this implementation
    # and just return :ok to accept all webhooks
    # In a production environment, you would want to properly verify the signature

    # TODO: Implement proper signature verification for production
    :ok
  end
end
