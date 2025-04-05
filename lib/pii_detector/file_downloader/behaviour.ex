defmodule PIIDetector.FileDownloader.Behaviour do
  @moduledoc """
  Defines the behaviour for file downloading and processing.
  """

  @doc """
  Downloads a file from a URL with authentication token.
  Returns {:ok, file_data} or {:error, reason}
  """
  @callback download_file(file :: map(), opts :: keyword()) :: {:ok, binary()} | {:error, any()}

  @doc """
  Processes an image file for AI analysis.
  Downloads the file and converts it to base64.
  Returns {:ok, processed_data} or {:error, reason}
  """
  @callback process_image(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, any()}

  @doc """
  Processes a PDF file for AI analysis.
  Downloads the file and converts it to base64.
  Returns {:ok, processed_data} or {:error, reason}
  """
  @callback process_pdf(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, any()}
end
