defmodule PIIDetector.AI.ClaudeService do
  @moduledoc """
  Implementation of AIServiceBehaviour using Claude API via Anthropix.
  """
  @behaviour PIIDetector.AI.AIServiceBehaviour

  require Logger

  @doc """
  Analyzes text for personally identifiable information (PII) using Claude API.
  """
  @impl true
  def analyze_pii(text) do
    # Initialize Anthropix client with API key
    client = anthropix_module().init(get_api_key())

    # Create the messages for Claude
    messages = [
      %{
        role: "user",
        content: create_pii_detection_prompt(text)
      }
    ]

    # Get the model name from config or environment variables
    model = get_model_name()

    # Send request to Claude through Anthropix
    case anthropix_module().chat(client,
           model: model,
           messages: messages,
           system: pii_detection_system_prompt(),
           temperature: 0.1,
           max_tokens: 1024
         ) do
      {:ok, response} ->
        parse_claude_response(response)

      {:error, reason} ->
        Logger.error("Claude API request failed #{inspect(reason)}")
        {:error, "Claude API request failed"}
    end
  end

  # Private helper functions

  defp anthropix_module do
    Application.get_env(:pii_detector, :anthropix_module, Anthropix)
  end

  defp get_api_key do
    System.get_env("CLAUDE_API_KEY") ||
      raise "CLAUDE_API_KEY environment variable is not set"
  end

  defp get_model_name do
    if Mix.env() == :prod do
      # Fallback default
      Application.get_env(:pii_detector, :claude)[:prod_model] ||
        System.get_env("CLAUDE_PROD_MODEL") ||
        "claude-3-sonnet-20240229"
    else
      # Fallback default
      Application.get_env(:pii_detector, :claude)[:dev_model] ||
        System.get_env("CLAUDE_DEV_MODEL") ||
        "claude-3-haiku-20240307"
    end
  end

  defp create_pii_detection_prompt(text) do
    """
    Analyze the following text for personally identifiable information (PII).

    Text to analyze:
    ```
    #{text}
    ```

    Respond with a JSON object with the following structure:
    {
      "has_pii": true/false,
      "categories": ["category1", "category2", ...],
      "explanation": "brief explanation"
    }

    Categories should be chosen from: ["email", "phone", "address", "name", "ssn", "credit_card", "date_of_birth", "financial", "medical", "credentials", "other"]
    """
  end

  defp pii_detection_system_prompt do
    """
    You are a PII detection system that identifies personally identifiable information in text.
    You will analyze text content and determine if it contains any PII.
    Respond ONLY with a JSON object, no preamble or additional text.

    Consider the following as PII:
    - Full names in conjunction with other identifying info
    - Email addresses
    - Phone numbers
    - Physical addresses
    - Social security numbers or government IDs
    - Credit card numbers
    - Dates of birth
    - Financial account details
    - Medical information
    - Credentials (usernames/passwords)

    When in doubt, be conservative and mark potential PII.
    """
  end

  defp parse_claude_response(response) do
    # Extract text from response
    text = extract_text_from_response(response)

    # Parse JSON from text
    case Jason.decode(text) do
      {:ok, decoded} ->
        {:ok,
         %{
           has_pii: decoded["has_pii"],
           categories: decoded["categories"] || [],
           explanation: decoded["explanation"]
         }}

      {:error, _} ->
        # Try extracting JSON from text
        case extract_json_from_text(text) do
          {:ok, decoded} ->
            {:ok,
             %{
               has_pii: decoded["has_pii"],
               categories: decoded["categories"] || [],
               explanation: decoded["explanation"]
             }}

          {:error, reason} ->
            Logger.error("Failed to parse Claude response", error: reason, response: text)
            {:error, "Failed to parse Claude response"}
        end
    end
  end

  defp extract_text_from_response(%{"content" => content}) do
    content
    |> Enum.filter(&(&1["type"] == "text"))
    |> Enum.map_join("\n", & &1["text"])
  end

  defp extract_json_from_text(text) do
    # Look for JSON pattern in text
    case Regex.run(~r/\{.*\}/s, text) do
      [json] ->
        Jason.decode(json)

      _ ->
        {:error, "No JSON found in response"}
    end
  end
end
