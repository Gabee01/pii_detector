defmodule PIIDetector.AI.ClaudeService do
  @moduledoc """
  Implementation of AI.Behaviour using Claude API via Anthropix.
  """
  @behaviour PIIDetector.AI.Behaviour

  require Logger

  @doc """
  Analyzes text for personally identifiable information (PII) using Claude API.
  """
  @impl true
  def analyze_pii(text) do
    # Initialize Anthropic client with API key
    client = anthropic_client().init(get_api_key())

    # Create the messages for Claude
    messages = [
      %{
        role: "user",
        content: create_pii_detection_prompt(text)
      }
    ]

    # Get the model name from config or environment variables
    model = get_model_name()

    # Send request to Claude through Anthropic client
    case anthropic_client().chat(client,
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

  @doc """
  Analyzes text and visual content for personally identifiable information (PII)
  using Claude's multimodal API capabilities.
  """
  @impl true
  def analyze_pii_multimodal(text, image_data, pdf_data) do
    # Initialize Anthropic client with API key
    client = anthropic_client().init(get_api_key())

    # Build content array with text and images/PDFs for multimodal request
    content = build_multimodal_content(text, image_data, pdf_data)

    # Create the messages for Claude
    messages = [
      %{
        role: "user",
        content: content
      }
    ]

    # Get the model name from config or environment variables
    model = get_model_name()

    # Send request to Claude through Anthropic client
    case anthropic_client().chat(client,
           model: model,
           messages: messages,
           system: pii_detection_system_prompt(),
           temperature: 0.1,
           max_tokens: 1024
         ) do
      {:ok, response} ->
        parse_claude_response(response)

      {:error, reason} ->
        Logger.error("Claude multimodal API request failed #{inspect(reason)}")
        {:error, "Claude multimodal API request failed"}
    end
  end

  # Private helper functions

  defp anthropic_client do
    Application.get_env(:pii_detector, :anthropic_client, PIIDetector.AI.Anthropic.Client)
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

  defp build_multimodal_content(text, image_data, pdf_data) do
    # Start with the text prompt
    prompt_text = create_pii_detection_prompt(text)

    content = [
      %{
        type: "text",
        text: prompt_text
      }
    ]

    # Add image if present
    content =
      if image_data do
        Logger.debug("Adding image to multimodal content: #{image_data.name || "unnamed"}")

        # Log image details for debugging
        Logger.debug("Image MIME type: #{image_data.mimetype}, size: #{byte_size(image_data.data) |> Base.decode64!() |> byte_size()} bytes")

        # Validate the image data
        if valid_multimodal_image?(image_data) do
          content ++
            [
              %{
                type: "image",
                source: %{
                  type: "base64",
                  media_type: image_data.mimetype,
                  data: image_data.data
                }
              }
            ]
        else
          Logger.error("Skipping invalid image data for multimodal request")
          content
        end
      else
        content
      end

    # Add PDF if present
    content =
      if pdf_data do
        Logger.debug("Adding PDF to multimodal content: #{pdf_data.name || "unnamed"}")

        # Log PDF details for debugging
        Logger.debug("PDF size: #{byte_size(pdf_data.data) |> Base.decode64!() |> byte_size()} bytes")

        # Validate the PDF data
        if valid_multimodal_pdf?(pdf_data) do
          content ++
            [
              %{
                type: "document",
                source: %{
                  type: "base64",
                  media_type: "application/pdf",
                  data: pdf_data.data
                }
              }
            ]
        else
          Logger.error("Skipping invalid PDF data for multimodal request")
          content
        end
      else
        content
      end

    content
  end

  # Check if image data is valid for multimodal request
  defp valid_multimodal_image?(%{data: data, mimetype: mimetype}) do
    # Ensure data is a valid base64 string
    case Base.decode64(data) do
      {:ok, decoded_data} ->
        # Ensure mimetype is supported
        supported_image_types = ["image/jpeg", "image/png", "image/gif", "image/webp"]
        if mimetype in supported_image_types do
          # Ensure size is within limits (3.75MB according to Anthropic docs)
          max_size = 3.75 * 1024 * 1024
          if byte_size(decoded_data) <= max_size do
            true
          else
            Logger.error("Image too large for Claude API: #{byte_size(decoded_data)} bytes")
            false
          end
        else
          Logger.error("Unsupported image type for Claude API: #{mimetype}")
          false
        end

      :error ->
        Logger.error("Invalid base64 encoding for image data")
        false
    end
  end

  defp valid_multimodal_image?(_), do: false

  # Check if PDF data is valid for multimodal request
  defp valid_multimodal_pdf?(%{data: data}) do
    # Ensure data is a valid base64 string
    case Base.decode64(data) do
      {:ok, decoded_data} ->
        # Ensure size is within limits (4.5MB according to Anthropic docs)
        max_size = 4.5 * 1024 * 1024
        if byte_size(decoded_data) <= max_size do
          # Basic check that it starts with the PDF signature
          if String.starts_with?(decoded_data, "%PDF-") do
            true
          else
            Logger.error("Invalid PDF format: data doesn't match PDF signature")
            false
          end
        else
          Logger.error("PDF too large for Claude API: #{byte_size(decoded_data)} bytes")
          false
        end

      :error ->
        Logger.error("Invalid base64 encoding for PDF data")
        false
    end
  end

  defp valid_multimodal_pdf?(_), do: false

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

    When analyzing images or PDFs:
    - Extract any text visible in the image/document and analyze it for PII
    - Look for ID cards, passports, driver's licenses, or other identity documents
    - Identify credit cards, bank statements, or other financial documents
    - Look for handwritten personal information
    - Detect screenshots of forms or websites containing personal information

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
