defmodule PIIDetector.Platform.Slack.APIBehaviour do
  @moduledoc """
  Behaviour module for Slack API interactions.
  This allows us to mock the Slack API calls in tests.
  """

  @doc """
  Posts a request to the Slack API.

  ## Parameters
  - endpoint: The Slack API endpoint
  - token: The Slack API token
  - params: The parameters to send to the API

  ## Returns
  - {:ok, response} on success
  - {:error, reason} on failure
  """
  @callback post(String.t(), String.t(), map()) :: {:ok, map()} | {:error, any()}

  @doc """
  Deletes a message from a channel.

  ## Parameters
  - channel: The channel ID
  - ts: The timestamp of the message
  - bot_token: The bot token to use as fallback

  ## Returns
  - {:ok, :deleted} on success
  - {:error, reason} on failure
  """
  @callback delete_message(String.t(), String.t(), String.t()) :: {:ok, :deleted} | {:error, any()}

  @doc """
  Sends a notification to a user about a deleted message.

  ## Parameters
  - user_id: The user ID to notify
  - message_content: The content of the deleted message
  - bot_token: The bot token to use for the API call

  ## Returns
  - {:ok, :notified} on success
  - {:error, reason} on failure
  """
  @callback notify_user(String.t(), map(), String.t()) :: {:ok, :notified} | {:error, any()}
end
