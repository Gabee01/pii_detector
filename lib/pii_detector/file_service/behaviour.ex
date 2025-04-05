defmodule PIIDetector.FileService.Behaviour do
  @moduledoc """
  Behaviour definition for file downloading and processing services.
  """

  @doc """
  Downloads a file from a URL with appropriate authentication.
  """
  @callback download_file(file :: map(), opts :: keyword()) :: {:ok, binary()} | {:error, any()}

  @doc """
  Process an image file for AI analysis.
  Typically converts to base64 and returns metadata.
  """
  @callback process_image(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Process a PDF file for AI analysis.
  Typically converts to base64 and returns metadata.
  """
  @callback process_pdf(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Process a document file (like Word, etc.) for AI analysis.
  Typically converts to base64 and returns metadata.
  """
  @callback process_document(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Process a text file for AI analysis.
  Typically converts to base64 and returns metadata.
  """
  @callback process_text(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Process any file regardless of type.
  Converts to base64 and returns metadata.
  """
  @callback process_generic_file(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Process a file based on its MIME type.
  Automatically determines file type and delegates to the appropriate processor.
  """
  @callback process_file(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}
end
