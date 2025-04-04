defmodule PIIDetector.Detector.PIIDetector do
  @moduledoc """
  Detects PII in content using Claude API via Anthropix.
  """
  @behaviour PIIDetector.Detector.PIIDetectorBehaviour

  require Logger

  @doc """
  Checks if the given content contains PII.
  Returns a tuple with {:pii_detected, true/false} and the categories of PII found.
  """
  @impl true
  def detect_pii(content) do
    # Extract all text content from message
    full_content = extract_full_content(content)

    if String.trim(full_content) == "" do
      # No content to analyze
      {:pii_detected, false, []}
    else
      case analyze_with_claude(full_content) do
        {:ok, %{has_pii: true, categories: categories}} ->
          {:pii_detected, true, categories}

        {:ok, %{has_pii: false}} ->
          {:pii_detected, false, []}

        {:error, reason} ->
          Logger.error("PII detection failed", error: reason)
          # Default to safe behavior if detection fails
          {:pii_detected, false, []}
      end
    end
  end

  # Private helper functions

  defp extract_full_content(content) do
    # Start with main text content
    text = content.text || ""

    # Add text from attachments
    attachment_text = content.attachments
      |> Enum.map(&extract_attachment_text/1)
      |> Enum.join("\n")

    # Add text from files (placeholder - will be implemented in Task 6)
    file_text = content.files
      |> Enum.map(&extract_file_text/1)
      |> Enum.join("\n")

    [text, attachment_text, file_text]
    |> Enum.filter(&(String.trim(&1) != ""))
    |> Enum.join("\n\n")
  end

  defp extract_attachment_text(attachment) when is_map(attachment) do
    attachment["text"] || ""
  end

  defp extract_attachment_text(_), do: ""

  defp extract_file_text(_file) do
    # Placeholder - will be implemented in Task 6
    ""
  end

  defp analyze_with_claude(text) do
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
    case anthropix_module().chat(client, [
      model: model,
      messages: messages,
      system: pii_detection_system_prompt(),
      temperature: 0.1,
      max_tokens: 1024
    ]) do
      {:ok, response} ->
        parse_claude_response(response)

      {:error, reason} ->
        Logger.error("Claude API request failed #{inspect(reason)}")
        {:error, "Claude API request failed"}
    end
  end

  defp anthropix_module do
    Application.get_env(:pii_detector, :anthropix_module, Anthropix)
  end

  defp get_api_key do
    System.get_env("CLAUDE_API_KEY") ||
      raise "CLAUDE_API_KEY environment variable is not set"
  end

  defp get_model_name do
    if Mix.env() == :prod do
      Application.get_env(:pii_detector, :claude)[:prod_model] ||
        System.get_env("CLAUDE_PROD_MODEL") ||
        "claude-3-sonnet-20240229" # Fallback default
    else
      Application.get_env(:pii_detector, :claude)[:dev_model] ||
        System.get_env("CLAUDE_DEV_MODEL") ||
        "claude-3-haiku-20240307" # Fallback default
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
        {:ok, %{
          has_pii: decoded["has_pii"],
          categories: decoded["categories"] || [],
          explanation: decoded["explanation"]
        }}

      {:error, _} ->
        # Try extracting JSON from text
        case extract_json_from_text(text) do
          {:ok, decoded} ->
            {:ok, %{
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
    |> Enum.filter(& &1["type"] == "text")
    |> Enum.map(& &1["text"])
    |> Enum.join("\n")
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
