defmodule PIIDetector.FileDownloader.Behaviour do
  @moduledoc """
  Behaviour definition for file downloading and processing.
  """

  @doc """
  Downloads a file from a URL with authentication token.
  Returns {:ok, file_data} or {:error, reason}
  """
  @callback download_file(file :: map(), opts :: keyword()) :: {:ok, binary()} | {:error, any()}

  @doc """
  Process an image file.
  """
  @callback process_image(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Process a PDF file.
  """
  @callback process_pdf(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}
end
