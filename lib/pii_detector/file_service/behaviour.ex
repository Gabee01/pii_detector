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
end
