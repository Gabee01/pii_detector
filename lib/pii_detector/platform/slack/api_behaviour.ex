defmodule PIIDetector.Platform.Slack.APIBehaviour do
  @moduledoc """
  Behaviour module for Slack API interactions.
  This allows us to mock the Slack API calls in tests.
  """

  @doc """
  Posts a request to the Slack API.
  """
  @callback post(endpoint :: String.t(), token :: String.t(), params :: map()) ::
              {:ok, map()} | {:error, any()}

  @doc """
  Posts a message to a Slack channel.
  """
  @callback post_message(
              channel :: String.t(),
              text :: String.t(),
              token :: String.t() | nil
            ) ::
              {:ok, map()} | {:error, any()}

  @doc """
  Posts an ephemeral message to a Slack channel that only a specific user can see.
  """
  @callback post_ephemeral_message(
              channel :: String.t(),
              user :: String.t(),
              text :: String.t(),
              token :: String.t() | nil
            ) ::
              {:ok, map()} | {:error, any()}

  @doc """
  Deletes a message from a channel.
  """
  @callback delete_message(
              channel :: String.t(),
              ts :: String.t(),
              token :: String.t() | nil
            ) ::
              {:ok, :deleted} | {:error, any()}

  @doc """
  Sends a notification to a user about a deleted message.
  """
  @callback notify_user(
              user_id :: String.t(),
              message_content :: map(),
              token :: String.t() | nil
            ) ::
              {:ok, :notified} | {:error, any()}

  @doc """
  Looks up a Slack user by their email address.
  """
  @callback users_lookup_by_email(email :: String.t(), token :: String.t() | nil) ::
              {:ok, map()} | {:error, any()}
end
