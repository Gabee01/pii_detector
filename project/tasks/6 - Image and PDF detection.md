# Content Type Processors: Refined Implementation Plan

## Current Code Analysis
Based on the codebase examination:

1. The PII detector is already set up to handle text content via `detect_pii/1`, with placeholders for file processing.
2. The Slack bot already captures files and attachments from messages and passes them to the worker.
3. The `extract_file_text/1` function in the PII detector is empty - this is where we need to implement our file processing.
4. The current Claude integration only sends text content for analysis.

## Step-by-Step Implementation

### 1. Enhance PIIDetector Module (3-4 hours)

#### Update PIIDetector.detect_pii function
- Update `extract_file_text/1` to process different file types:
  ```elixir
  defp extract_file_text(file) do
    case file["mimetype"] do
      "image/" <> _type -> 
        process_image_file(file)
      "application/pdf" ->
        process_pdf_file(file)
      _ ->
        "" # Ignore other file types for now
    end
  end
  ```

#### Implement image processing
```elixir
defp process_image_file(file) do
  # Get file from Slack API
  case download_file(file["url_private"]) do
    {:ok, image_data} ->
      # Convert to base64 for Claude API
      base64_data = Base.encode64(image_data)
      # Store for later use in analyze_with_claude_multimodal
      Process.put(:image_data, %{
        data: base64_data,
        mimetype: file["mimetype"]
      })
      "" # Return empty string as we'll handle the image separately
    {:error, reason} ->
      Logger.error("Failed to download image: #{inspect(reason)}")
      ""
  end
end
```

#### Implement PDF processing
```elixir
defp process_pdf_file(file) do
  # Get file from Slack API
  case download_file(file["url_private"]) do
    {:ok, pdf_data} ->
      # Convert to base64 for Claude API
      base64_data = Base.encode64(pdf_data)
      # Store for later use in analyze_with_claude_multimodal
      Process.put(:pdf_data, %{
        data: base64_data,
        mimetype: "application/pdf"
      })
      "" # Return empty string as we'll handle the PDF separately
    {:error, reason} ->
      Logger.error("Failed to download PDF: #{inspect(reason)}")
      ""
  end
end
```

#### Add the download_file helper
```elixir
defp download_file(url) do
  # Use HTTPoison or similar to download file with Slack token for authentication
  headers = [
    {"Authorization", "Bearer #{get_slack_token()}"}
  ]
  
  case HTTPoison.get(url, headers) do
    {:ok, %{status_code: 200, body: body}} ->
      {:ok, body}
    {:ok, %{status_code: status}} ->
      {:error, "Failed to download file, status: #{status}"}
    {:error, error} ->
      {:error, error}
  end
end

defp get_slack_token do
  System.get_env("SLACK_BOT_TOKEN") ||
    raise "SLACK_BOT_TOKEN environment variable is not set"
end
```

#### Create multimodal Claude integration
```elixir
defp analyze_with_claude(text) do
  # Check if we have image or PDF data stored
  image_data = Process.get(:image_data)
  pdf_data = Process.get(:pdf_data)
  
  if image_data || pdf_data do
    # Use multimodal API if we have visual content
    analyze_with_claude_multimodal(text, image_data, pdf_data)
  else
    # Use text-only API for simple text messages
    # (existing implementation)
    ...
  end
end

defp analyze_with_claude_multimodal(text, image_data, pdf_data) do
  # Initialize Anthropix client with API key
  client = anthropix_module().init(get_api_key())
  
  # Build content array for multimodal request
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
  
  # Send request to Claude through Anthropix
  case anthropix_module().chat(client,
         model: model,
         messages: messages,
         system: pii_detection_system_prompt(),
         temperature: 0.1,
         max_tokens: 1024
       ) do
    {:ok, response} ->
      # Clean up stored data
      Process.delete(:image_data)
      Process.delete(:pdf_data)
      
      parse_claude_response(response)
    
    {:error, reason} ->
      # Clean up stored data
      Process.delete(:image_data)
      Process.delete(:pdf_data)
      
      Logger.error("Claude API request failed #{inspect(reason)}")
      {:error, "Claude API request failed"}
  end
end

defp build_multimodal_content(text, image_data, pdf_data) do
  # Start with the text prompt
  content = [
    %{
      type: "text", 
      text: create_pii_detection_prompt(text)
    }
  ]
  
  # Add image if present
  content = if image_data do
    content ++ [
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
    content
  end
  
  # Add PDF if present
  content = if pdf_data do
    content ++ [
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
    content
  end
  
  content
end
```

### 2. Update SlackMessageWorker (1-2 hours)

The current worker passes all message content to the detector, but we need to ensure the file URLs are accessible:

```elixir
def perform(%Oban.Job{args: args}) do
  %{
    "channel" => channel,
    "user" => user,
    "ts" => ts,
    "token" => token,
    "files" => files
  } = args
  
  # Process files if they exist
  processed_files = if files && files != [], do: process_files(files, token), else: []
  
  # Extract message content for PII detection
  message_content = %{
    text: args["text"] || "",
    files: processed_files,
    attachments: args["attachments"] || []
  }
  
  # Then continue with PII detection...
end

defp process_files(files, token) do
  # Ensure necessary fields are present for the PIIDetector to process
  Enum.map(files, fn file ->
    # Add token to file object if not already present
    # This ensures authorization when downloading files
    Map.put_new(file, "token", token)
  end)
end
```

### 3. Update MessageFormatter (1-2 hours)

Update the notification message to include information about files:

```elixir
def format_pii_notification(original_content) do
  # Build file info text
  file_info = if original_content.files && original_content.files != [] do
    file_names = original_content.files
                 |> Enum.map(fn file -> file["name"] end)
                 |> Enum.join(", ")
    
    "\nYour message also contained files: #{file_names}"
  else
    ""
  end

  """
  :warning: Your message was removed because it contained personal identifiable information (PII).

  Please repost your message without including sensitive information such as:
  • Social security numbers
  • Credit card numbers
  • Personal addresses
  • Full names with contact information
  • Email addresses
  
  Here's your original message for reference:
  ```
  #{original_content.text}
  ```
  #{file_info}
  """
end
```

### 4. Update Anthropix Client (1-2 hours)

Ensure the Anthropix library can handle multimodal content. If it doesn't support the latest Claude API features, we may need to:

```elixir
# If Anthropix doesn't support multimodal content, we might need to create a custom client:
defmodule PIIDetector.Claude.Client do
  @moduledoc """
  Custom Claude API client that supports multimodal content.
  """
  
  def init(api_key) do
    %{api_key: api_key}
  end
  
  def chat(%{api_key: api_key}, opts) do
    url = "https://api.anthropic.com/v1/messages"
    
    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]
    
    # Extract options
    messages = Keyword.get(opts, :messages, [])
    system = Keyword.get(opts, :system)
    model = Keyword.get(opts, :model, "claude-3-sonnet-20240229")
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 1024)
    
    # Build request body
    body = %{
      model: model,
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature
    }
    
    # Add system prompt if provided
    body = if system, do: Map.put(body, :system, system), else: body
    
    # Send request
    case HTTPoison.post(url, Jason.encode!(body), headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}
        
      {:ok, %{status_code: status, body: response_body}} ->
        {:error, "API request failed with status #{status}: #{response_body}"}
        
      {:error, error} ->
        {:error, error}
    end
  end
end
```

### 5. Testing (3-4 hours)

Add or update tests for:

1. Image processing with different formats
2. PDF processing
3. Multimodal Claude API calls
4. Error handling for file downloads

```elixir
# Example test for multimodal PII detection
test "detects PII in images" do
  image_data = File.read!("test/fixtures/pii_image.jpg")
  base64_image = Base.encode64(image_data)
  
  # Set process data to simulate image processing
  Process.put(:image_data, %{
    data: base64_image,
    mimetype: "image/jpeg"
  })
  
  # Set mock response
  Process.put(
    :anthropix_response,
    {:ok,
     %{
       "content" => [
         %{
           "type" => "text",
           "text" => ~s({"has_pii": true, "categories": ["credit_card"], "explanation": "Image contains credit card"})
         }
       ]
     }}
  )
  
  content = %{text: "Check out this image", files: [%{"mimetype" => "image/jpeg"}], attachments: []}
  
  assert {:pii_detected, true, ["credit_card"]} = PIIDetector.detect_pii(content)
  
  # Verify cleanup
  assert Process.get(:image_data) == nil
end
```

### 6. Dockerize and Deploy (2-3 hours)

Update Dockerfile to include any dependencies needed for file processing:

```dockerfile
# Ensure we have necessary libraries for image processing
RUN apt-get update && \
    apt-get install -y \
    file \
    imagemagick \
    libmagic-dev \
    && rm -rf /var/lib/apt/lists/*
```

## Implementation Timeline

- Day 1 (Afternoon): 
  - Enhance PIIDetector module (3-4 hours)
  - Update SlackMessageWorker (1-2 hours)
  
- Day 1 (Evening):
  - Update MessageFormatter (1-2 hours)
  - Update or create custom Anthropix client if needed (1-2 hours)
  
- Day 2 (Morning):
  - Testing (3-4 hours)
  - Dockerize and deploy (2-3 hours)

## Technical Considerations

1. **File size limits**: 
   - Claude API limits image size to 8000x8000 px
   - PDF size limit is 32MB and 100 pages per request

2. **Token usage**:
   - Each image uses tokens based on its size (approx 1,600 tokens for 1.15MP image)
   - PDFs use 1,500-3,000 tokens per page

3. **Error handling**:
   - File download failures should be logged but not crash the worker
   - Consider fallback mechanisms if file processing fails

4. **Security**:
   - Ensure files are securely downloaded (with proper auth)
   - Don't persist files unnecessarily
   - Clean up temporary files and process data

## Next Steps After Implementation

1. Thorough testing with various file types containing PII
2. Performance monitoring of the Claude API calls with multimodal content
3. Prepare for Notion integration next