defmodule PIIDetector.Slack.APIBehaviour do
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
end
