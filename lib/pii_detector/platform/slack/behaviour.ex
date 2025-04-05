defmodule PIIDetector.Platform.Slack.Behaviour do
  @moduledoc """
  Behaviour module for Slack platform functionality.
  This defines the interface for the Slack platform context.
  """

  @doc """
  Posts a message to a Slack channel.
  """
  @callback post_message(channel :: String.t(), text :: String.t(), token :: String.t() | nil) ::
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
  Deletes a message from a Slack channel.
  """
  @callback delete_message(channel :: String.t(), ts :: String.t(), token :: String.t() | nil) ::
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
  Formats a message for PII notification.
  """
  @callback format_pii_notification(message_content :: map()) :: String.t()
end
