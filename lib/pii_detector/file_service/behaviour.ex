defmodule PIIDetector.FileService.Behaviour do
  @moduledoc """
  Behaviour definition for file downloading and basic processing services.
  This module focuses on downloading files and preparing them for content analysis,
  following the Single Responsibility Principle.
  """

  @doc """
  Downloads a file from a URL with appropriate authentication.
  """
  @callback download_file(file :: map(), opts :: keyword()) :: {:ok, binary()} | {:error, any()}

  @doc """
  Prepares a file for analysis by downloading it and encoding it to base64.
  Returns the file data along with metadata (mimetype, name).
  """
  @callback prepare_file(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}

  # Deprecated callbacks - kept for backward compatibility
  # These should be removed in future versions

  @doc """
  DEPRECATED: Use prepare_file/2 instead.
  """
  @callback process_image(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  DEPRECATED: Use prepare_file/2 instead.
  """
  @callback process_pdf(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  DEPRECATED: Use prepare_file/2 instead.
  """
  @callback process_document(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  DEPRECATED: Use prepare_file/2 instead.
  """
  @callback process_text(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  DEPRECATED: Use prepare_file/2 instead.
  """
  @callback process_generic_file(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  DEPRECATED: Use prepare_file/2 instead.
  """
  @callback process_file(file :: map(), opts :: keyword()) :: {:ok, map()} | {:error, String.t()}
end
