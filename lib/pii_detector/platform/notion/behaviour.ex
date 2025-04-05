defmodule PIIDetector.Platform.Notion.Behaviour do
  @moduledoc """
  Behaviour module defining the Notion platform interface.
  """

  @callback extract_content_from_page(page_data :: map(), blocks :: list(map())) ::
              {:ok, String.t()} | {:error, any()}

  @callback extract_content_from_blocks(blocks :: list(map())) ::
              {:ok, String.t()} | {:error, any()}

  @callback extract_content_from_database(database_data :: list(map())) ::
              {:ok, String.t()} | {:error, any()}

  @callback extract_page_content(
              page_result :: {:ok, map()} | {:error, any()},
              blocks_result :: {:ok, list(map())} | {:error, any()}
            ) ::
              {:ok, String.t(), list(map())} | {:error, any()}

  @callback archive_content(content_id :: String.t()) ::
              {:ok, map()} | {:error, any()}

  @callback notify_content_creator(
              user_id :: String.t(),
              content :: String.t(),
              detected_pii :: map()
            ) ::
              {:ok, any()} | {:error, any()}
end
