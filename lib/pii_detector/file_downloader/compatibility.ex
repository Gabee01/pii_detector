defmodule PIIDetector.FileDownloader.Compatibility do
  @moduledoc """
  Compatibility layer for the old FileDownloader.Behaviour interface.

  This module implements the old FileDownloader.Behaviour interface but
  delegates to the new FileService implementation. This allows for a gradual
  transition to the new architecture without breaking existing code.
  """

  @behaviour PIIDetector.FileDownloader.Behaviour

  require Logger

  @impl true
  def download_file(%{"url_private" => url} = file, opts) do
    file_service = get_file_service()

    # Convert the old format to the new format
    headers =
      case file do
        %{"headers" => headers} when is_list(headers) -> headers
        %{"token" => token} when is_binary(token) -> [{"Authorization", "Bearer #{token}"}]
        _ -> []
      end

    adapted_file = %{
      "url" => url,
      "headers" => headers
    }

    file_service.download_file(adapted_file, opts)
  end

  @impl true
  def process_image(%{"url_private" => url, "mimetype" => mimetype} = file, opts) do
    file_service = get_file_service()

    # Convert the old format to the new format
    headers =
      case file do
        %{"headers" => headers} when is_list(headers) -> headers
        %{"token" => token} when is_binary(token) -> [{"Authorization", "Bearer #{token}"}]
        _ -> []
      end

    adapted_file = %{
      "url" => url,
      "mimetype" => mimetype,
      "name" => file["name"],
      "headers" => headers
    }

    file_service.process_image(adapted_file, opts)
  end

  @impl true
  def process_pdf(%{"url_private" => url} = file, opts) do
    file_service = get_file_service()

    # Convert the old format to the new format
    headers =
      case file do
        %{"headers" => headers} when is_list(headers) -> headers
        %{"token" => token} when is_binary(token) -> [{"Authorization", "Bearer #{token}"}]
        _ -> []
      end

    adapted_file = %{
      "url" => url,
      "mimetype" => "application/pdf",
      "name" => file["name"],
      "headers" => headers
    }

    file_service.process_pdf(adapted_file, opts)
  end

  defp get_file_service do
    Application.get_env(:pii_detector, :file_service, PIIDetector.FileService.Processor)
  end
end
