defmodule PIIDetector.Platform.Notion.EventDataExtractor do
  @moduledoc """
  Extracts relevant data from Notion webhook events.

  This module is responsible for extracting important data from different
  formats of Notion webhook events, such as page IDs and user IDs.
  """

  require Logger

  @doc """
  Extract page ID from a Notion event.

  Handles various event formats from Notion's webhook payloads.

  ## Parameters
  - event: The Notion event data (map)

  ## Returns
  - String.t() | nil: The extracted page ID or nil if not found
  """
  def get_page_id_from_event(%{"page" => %{"id" => page_id}}) when is_binary(page_id) do
    Logger.debug("Extracted page_id from page.id: #{page_id}")
    page_id
  end

  def get_page_id_from_event(%{"page_id" => page_id}) when is_binary(page_id) do
    Logger.debug("Extracted page_id from page_id field: #{page_id}")
    page_id
  end

  def get_page_id_from_event(%{"entity" => %{"id" => page_id, "type" => "page"}})
      when is_binary(page_id) do
    Logger.debug("Extracted page_id from entity.id: #{page_id}")
    page_id
  end

  def get_page_id_from_event(event) do
    Logger.warning("Could not extract page_id from event: #{inspect(event)}")
    nil
  end

  @doc """
  Extract user ID from a Notion event.

  Handles various event formats from Notion's webhook payloads.

  ## Parameters
  - event: The Notion event data (map)

  ## Returns
  - String.t() | nil: The extracted user ID or nil if not found
  """
  def get_user_id_from_event(%{"user" => %{"id" => user_id}}) when is_binary(user_id) do
    Logger.debug("Extracted user_id from user.id: #{user_id}")
    user_id
  end

  def get_user_id_from_event(%{"user_id" => user_id}) when is_binary(user_id) do
    Logger.debug("Extracted user_id from user_id field: #{user_id}")
    user_id
  end

  def get_user_id_from_event(%{"authors" => [%{"id" => user_id} | _]}) when is_binary(user_id) do
    Logger.debug("Extracted user_id from authors array: #{user_id}")
    user_id
  end

  def get_user_id_from_event(event) do
    Logger.warning("Could not extract user_id from event: #{inspect(event)}")
    nil
  end
end
