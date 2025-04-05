defmodule PIIDetector.AI.ClaudeService do
  @moduledoc """
  Implementation of AI.Behaviour using Claude API via Anthropix.

  This module is responsible for:

  * Communicating with Anthropic's Claude API for PII detection
  * Processing both text-only and multimodal (text + images/PDFs) content
  * Building properly formatted requests for Claude's API
  * Validating responses and extracting structured data
  * Handling base64-encoded content to detect potential HTML content

  The multimodal processing allows for PII detection in:
  * Text messages
  * Image files (JPG, PNG, etc.)
  * PDF documents

  The service includes validation to prevent sending problematic data to Claude's API,
  such as HTML content that might be returned by Slack instead of actual file data.
  """
  @behaviour PIIDetector.AI.Behaviour

  require Logger

  @doc """
  Analyzes text for personally identifiable information (PII) using Claude API.

  This function:
  1. Initializes the Anthropic client with API key
  2. Creates a structured prompt for PII detection
  3. Sends the request to Claude's API
  4. Parses and normalizes the response

  ## Parameters

  * `text` - The text content to analyze for PII

  ## Returns

  * `{:ok, result}` - Map containing:
    * `has_pii` - Boolean indicating if PII was detected
    * `categories` - List of PII categories found (e.g. "email", "phone")
    * `explanation` - Human-readable explanation of the findings
  * `{:error, reason}` - Error description if the analysis failed
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

  This function handles three types of content simultaneously:
  1. Text data for analysis
  2. Optional image data (JPEG, PNG, etc.) in base64 format
  3. Optional PDF data in base64 format

  The function:
  1. Initializes the Anthropic client with API key
  2. Builds a multimodal content array combining text, images, and/or PDFs
  3. Validates base64 data to filter out HTML content that may cause API errors
  4. Sends the multimodal request to Claude's API
  5. Parses and normalizes the response

  ## Parameters

  * `text` - The text content to analyze for PII
  * `image_data` - Optional map with base64-encoded image details:
    * `data` - Base64-encoded image content
    * `mimetype` - The MIME type of the image
    * `name` - Filename or identifier
  * `pdf_data` - Optional map with base64-encoded PDF details:
    * `data` - Base64-encoded PDF content
    * `mimetype` - Should be "application/pdf"
    * `name` - Filename or identifier

  ## Returns

  * `{:ok, result}` - Map containing:
    * `has_pii` - Boolean indicating if PII was detected
    * `categories` - List of PII categories found (e.g. "email", "phone")
    * `explanation` - Human-readable explanation of the findings
  * `{:error, reason}` - Error description if the analysis failed
  """
  @impl true
  def analyze_pii_multimodal(text, image_data, pdf_data) do
    # Initialize Anthropic client with API key
    client = anthropic_client().init(get_api_key())

    # Choose which file data to use (prefer image data if present)
    file_data = case {image_data, pdf_data} do
      {nil, nil} -> nil
      {nil, pdf} -> pdf
      {img, _} -> img
    end

    # Build content array with text and file data for multimodal request
    content = build_multimodal_content(text, file_data)

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

  @doc false
  # Builds a content array suitable for Claude's multimodal API combining text with a file
  defp build_multimodal_content(text, file_data) do
    # Start with the text prompt
    prompt_text = create_pii_detection_prompt(text)

    content = [
      %{
        type: "text",
        text: prompt_text
      }
    ]

    # Add file if present
    content = add_image_to_content(content, file_data)

    Logger.debug("Built multimodal content with file: #{inspect(file_data != nil)}")

    content
  end

  @doc false
  # Adds image data to the multimodal content array if present and valid
  defp add_image_to_content(content, image_data) do
    Logger.debug("Adding file to multimodal content: #{inspect(image_data)}")

    # Early return if no data
    if image_data == nil do
      Logger.debug("No file data to add to multimodal content")
      content
    else
      # Normalize the data structure - support both atom and string keys
      name = image_data[:name] || image_data["name"] || "unnamed"
      mimetype = image_data[:mimetype] || image_data["mimetype"] || "application/octet-stream"
      data = image_data[:data] || image_data["data"]

      Logger.debug("File name: #{name}, mimetype: #{mimetype}, data length: #{String.length(data)}")

      # Check if the base64 data appears to be HTML content
      if html_base64?(data) do
        Logger.error("Detected HTML content in base64 data - not adding file")
        content
      else
        # Determine the appropriate format based on MIME type
        {type, media_type} = case mimetype do
          "application/pdf" ->
            {"document", "application/pdf"}
          mime when mime in ["image/png", "image/jpeg", "image/jpg", "image/gif", "image/webp"] ->
            {"image", mime}
          _ ->
            # Default to image type for any other file, Claude will try its best
            {"image", mimetype}
        end

        Logger.debug("Adding file as type: #{type}, media_type: #{media_type}")

        updated_content = content ++
          [
            %{
              type: type,
              source: %{
                type: "base64",
                media_type: media_type,
                data: data
              }
            }
          ]

        Logger.debug("Successfully added file to multimodal content")
        updated_content
      end
    end
  end

  @doc false
  # Detects if base64 data appears to be encoded HTML content
  # This prevents sending HTML error pages to Claude's API
  defp html_base64?(base64_data) do
    # Check common HTML patterns in base64
    html_patterns = [
      # <!DOCTY
      "PCFET0NUWV",
      # <html
      "PGh0bWw",
      # <xml
      "PHhtbC",
      # <head
      "PGhlYWQ",
      # <body
      "PGJvZHk"
    ]

    Enum.any?(html_patterns, fn pattern ->
      String.starts_with?(base64_data, pattern)
    end)
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
