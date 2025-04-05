defmodule PIIDetector.Platform.Notion.PIIPatterns do
  @moduledoc """
  Fast path patterns for detecting obvious PII in Notion content.

  This module provides regex patterns and utilities for quick checks of
  common PII patterns in Notion content, especially useful for title scans
  before doing a more expensive full content analysis.
  """

  @doc """
  Checks for common PII patterns in the given text.

  ## Parameters
  - text: The text to check for PII patterns

  ## Returns
  - {:pii_detected, true, categories} if PII is found, with categories as a list of strings
  - false if no PII is detected
  """
  def check_for_obvious_pii(nil), do: false
  def check_for_obvious_pii(""), do: false

  def check_for_obvious_pii(text) when is_binary(text) do
    # Define common PII regex patterns
    email_pattern = ~r/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/
    ssn_pattern = ~r/\b\d{3}[-.]?\d{2}[-.]?\d{4}\b/
    phone_pattern = ~r/\b(\+\d{1,2}\s?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b/
    credit_card_pattern = ~r/\b(?:\d{4}[-\s]?){3}\d{4}\b|\b\d{16}\b/

    cond do
      Regex.match?(email_pattern, text) ->
        {:pii_detected, true, ["email"]}

      Regex.match?(ssn_pattern, text) ->
        {:pii_detected, true, ["ssn"]}

      Regex.match?(phone_pattern, text) ->
        {:pii_detected, true, ["phone"]}

      Regex.match?(credit_card_pattern, text) ->
        {:pii_detected, true, ["credit_card"]}

      true ->
        false
    end
  end

  @doc """
  Extract the title from a Notion page object.

  ## Parameters
  - page: The Notion page object

  ## Returns
  - String.t() | nil: The page title or nil if not found
  """
  def extract_page_title(page) when is_map(page) do
    case get_in(page, ["properties", "title", "title"]) do
      nil ->
        nil

      rich_text_list when is_list(rich_text_list) ->
        rich_text_list
        |> Enum.map(fn item -> get_in(item, ["plain_text"]) end)
        |> Enum.filter(&(&1 != nil))
        |> Enum.join("")
    end
  end

  def extract_page_title(_), do: nil
end
