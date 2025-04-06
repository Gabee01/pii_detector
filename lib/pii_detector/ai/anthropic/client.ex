defmodule PIIDetector.AI.Anthropic.Client do
  @moduledoc """
  Implementation of the Anthropic.Behaviour using the Anthropix library.
  """
  @behaviour PIIDetector.AI.Anthropic.Behaviour

  require Logger

  @impl true
  def init(api_key) do
    if is_nil(api_key) || api_key == "" do
      Logger.error("Attempted to initialize Anthropic client with nil or empty API key")
      raise ArgumentError, "API key cannot be nil or empty"
    end

    # Mask API key for logging
    masked_key = String.slice(api_key, 0, 4) <> "..." <> String.slice(api_key, -4, 4)
    Logger.debug("Initializing Anthropic client with API key (masked): #{masked_key}")

    # Wrap in try/catch to handle potential errors from external library
    try do
      client = Anthropix.init(api_key)
      Logger.debug("Anthropic client initialized successfully")
      client
    rescue
      e ->
        Logger.error("Failed to initialize Anthropic client: #{inspect(e)}")
        reraise e, __STACKTRACE__
    end
  end

  @impl true
  def chat(client, opts) do
    # Log request details (excluding sensitive content)
    safe_opts = %{
      model: opts[:model],
      temperature: opts[:temperature],
      max_tokens: opts[:max_tokens]
    }

    Logger.debug("Anthropic chat request: #{inspect(safe_opts)}")

    # Track timing for API call
    start_time = System.monotonic_time(:millisecond)

    # Wrap the external API call to capture and handle errors
    try do
      result = Anthropix.chat(client, opts)

      end_time = System.monotonic_time(:millisecond)
      elapsed_ms = end_time - start_time

      case result do
        {:ok, response} ->
          Logger.debug("Anthropic API call successful in #{elapsed_ms}ms")
          {:ok, response}

        {:error, error} ->
          Logger.error("Anthropic API error in #{elapsed_ms}ms: #{inspect(error)}")
          {:error, error}
      end
    rescue
      e ->
        end_time = System.monotonic_time(:millisecond)
        elapsed_ms = end_time - start_time

        Logger.error("Anthropic API exception after #{elapsed_ms}ms: #{inspect(e)}")
        {:error, %{reason: "exception", error: inspect(e)}}
    catch
      kind, reason ->
        end_time = System.monotonic_time(:millisecond)
        elapsed_ms = end_time - start_time

        Logger.error("Anthropic API #{kind} after #{elapsed_ms}ms: #{inspect(reason)}")
        {:error, %{reason: "#{kind}", error: inspect(reason)}}
    end
  end
end
