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
    api_key = get_api_key()
    Logger.debug("Initializing Anthropic client for text-only analysis")

    # Log for debugging but mask the actual API key value
    masked_key =
      if api_key,
        do: String.slice(api_key, 0, 4) <> "..." <> String.slice(api_key, -4, 4),
        else: "nil"

    Logger.debug("Using API key (masked): #{masked_key}")

    client = anthropic_client().init(api_key)

    # Create the messages for Claude
    messages = [
      %{
        role: "user",
        content: create_pii_detection_prompt(text)
      }
    ]

    # Get the model name from config or environment variables
    model = get_model_name()
    Logger.info("Using Claude model: #{model} for text-only analysis")

    # Send request to Claude through Anthropic client
    Logger.debug("Sending request to Claude API")

    request_opts = [
      model: model,
      messages: messages,
      system: pii_detection_system_prompt(),
      temperature: 0.1,
      max_tokens: 1024
    ]

    Logger.debug(
      "Request options: #{inspect(%{model: model, temperature: 0.1, max_tokens: 1024})}"
    )

    case anthropic_client().chat(client, request_opts) do
      {:ok, response} ->
        Logger.debug("Received successful response from Claude API")
        parse_claude_response(response)

      {:error, reason} ->
        # More detailed error logging to help debug issues
        error_details = inspect(reason)
        Logger.error("Claude API request failed", error: error_details)

        # Include additional context in logs
        Logger.error("Claude API request context",
          model: model,
          text_length: String.length(text),
          error_type: if(is_map(reason), do: Map.get(reason, :reason, "unknown"), else: "unknown")
        )

        {:error, "Claude API request failed: #{error_details}"}
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
    # Initialize client and prepare request data
    {client, file_data, file_type} = prepare_multimodal_request(image_data, pdf_data)

    # Build content and create request options
    {_messages, model, request_opts} = build_multimodal_request(text, file_data, file_type)

    # Send request to Claude API and handle response
    send_multimodal_request(client, request_opts, model, text, file_type)
  end

  # Prepares the client and file data for multimodal request
  defp prepare_multimodal_request(image_data, pdf_data) do
    # Initialize Anthropic client with API key
    api_key = get_api_key()
    Logger.debug("Initializing Anthropic client for multimodal analysis")

    # Log for debugging but mask the actual API key value
    masked_key =
      if api_key,
        do: String.slice(api_key, 0, 4) <> "..." <> String.slice(api_key, -4, 4),
        else: "nil"

    Logger.debug("Using API key (masked): #{masked_key}")

    client = anthropic_client().init(api_key)

    # Choose which file data to use (prefer image data if present)
    file_data =
      case {image_data, pdf_data} do
        {nil, nil} -> nil
        {nil, pdf} -> pdf
        {img, _} -> img
      end

    # Determine file type for logging
    file_type =
      cond do
        image_data != nil -> "image"
        pdf_data != nil -> "pdf"
        true -> "none"
      end

    {client, file_data, file_type}
  end

  # Builds the request options for multimodal API
  defp build_multimodal_request(text, file_data, file_type) do
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
    Logger.info("Using Claude model: #{model} for multimodal analysis")

    # Create request options
    request_opts = [
      model: model,
      messages: messages,
      system: pii_detection_system_prompt(),
      temperature: 0.1,
      max_tokens: 1024
    ]

    Logger.debug(
      "Request options: #{inspect(%{model: model, temperature: 0.1, max_tokens: 1024, file_type: file_type})}"
    )

    {messages, model, request_opts}
  end

  # Sends the request to Claude and handles the response
  defp send_multimodal_request(client, request_opts, model, text, file_type) do
    Logger.debug("Sending multimodal request to Claude API")

    case anthropic_client().chat(client, request_opts) do
      {:ok, response} ->
        Logger.debug("Received successful response from Claude API (multimodal)")
        parse_claude_response(response)

      {:error, reason} ->
        # More detailed error logging to help debug issues
        error_details = inspect(reason)
        Logger.error("Claude multimodal API request failed", error: error_details)

        # Include additional context in logs
        Logger.error("Claude multimodal API request context",
          model: model,
          text_length: String.length(text),
          file_type: file_type,
          error_type: if(is_map(reason), do: Map.get(reason, :reason, "unknown"), else: "unknown")
        )

        {:error, "Claude multimodal API request failed: #{error_details}"}
    end
  end

  # Private helper functions

  defp anthropic_client do
    Application.get_env(:pii_detector, :anthropic_client, PIIDetector.AI.Anthropic.Client)
  end

  defp get_api_key do
    key = System.get_env("CLAUDE_API_KEY")

    if is_nil(key) || key == "" do
      Logger.error("CLAUDE_API_KEY environment variable is not set or is empty")
      raise "CLAUDE_API_KEY environment variable is not set"
    else
      key
    end
  end

  defp get_model_name do
    Application.get_env(:pii_detector, :claude)[:model] || "claude-3-7-sonnet-20250219"
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
      add_valid_image_to_content(content, image_data)
    end
  end

  # Helper function to process valid image data and add it to content
  defp add_valid_image_to_content(content, image_data) do
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
      append_file_content(content, mimetype, data)
    end
  end

  # Helper function to determine the file type and append to content
  defp append_file_content(content, mimetype, data) do
    {type, media_type} = get_file_type_and_media(mimetype)
    Logger.debug("Adding file as type: #{type}, media_type: #{media_type}")

    updated_content =
      content ++
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

  # Helper function to determine file type and media type based on mimetype
  defp get_file_type_and_media(mimetype) do
    case mimetype do
      "application/pdf" ->
        {"document", "application/pdf"}

      mime
      when mime in ["image/png", "image/jpeg", "image/jpg", "image/gif", "image/webp"] ->
        {"image", mime}

      _ ->
        # Default to image type for any other file, Claude will try its best
        {"image", mimetype}
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
