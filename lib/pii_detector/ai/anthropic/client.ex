defmodule PIIDetector.AI.Anthropic.Client do
  @moduledoc """
  Implementation of the Anthropic.Behaviour using the Anthropix library.
  """
  @behaviour PIIDetector.AI.Anthropic.Behaviour

  require Logger

  @impl true
  def init(api_key) do
    Anthropix.init(api_key)
  end

  @impl true
  def chat(client, opts) do
    Logger.debug("Anthropic chat request: #{inspect(opts)}")
    Anthropix.chat(client, opts)
  end
end
