defmodule PIIDetector.Platform.Notion.APIBehaviour do
  @moduledoc """
  Behaviour module defining the Notion API interface.
  """

  @callback get_page(page_id :: String.t(), token :: String.t() | nil, opts :: Keyword.t()) ::
              {:ok, map()} | {:error, any()}

  @callback get_blocks(page_id :: String.t(), token :: String.t() | nil, opts :: Keyword.t()) ::
              {:ok, list(map())} | {:error, any()}

  @callback get_database_entries(
              database_id :: String.t(),
              token :: String.t() | nil,
              opts :: Keyword.t()
            ) ::
              {:ok, list(map())} | {:error, any()}

  @callback archive_page(page_id :: String.t(), token :: String.t() | nil, opts :: Keyword.t()) ::
              {:ok, map()} | {:error, any()}

  @callback archive_database_entry(
              page_id :: String.t(),
              token :: String.t() | nil,
              opts :: Keyword.t()
            ) ::
              {:ok, map()} | {:error, any()}

  @callback get_user(
              user_id :: String.t(),
              token :: String.t() | nil,
              opts :: Keyword.t()
            ) ::
              {:ok, map()} | {:error, any()}
end
