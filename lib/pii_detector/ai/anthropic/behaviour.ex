defmodule PIIDetector.AI.Anthropic.Behaviour do
  @moduledoc """
  Behaviour definition for Anthropic API client interactions.
  This allows us to easily mock Claude API calls in tests.
  """

  @type client :: map()
  @type chat_response :: {:ok, map()} | {:error, any()}

  @callback init(api_key :: String.t()) :: client()
  @callback chat(
              client :: client(),
              opts :: keyword()
            ) :: chat_response()
end
