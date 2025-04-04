defmodule PIIDetector.AI.MockService do
  @moduledoc """
  Mock implementation of AIServiceBehaviour for testing.
  This module provides predefined responses for testing without making actual API calls.
  """
  @behaviour PIIDetector.AI.AIServiceBehaviour

  require Logger

  @doc """
  Mock implementation of analyze_pii.
  Returns predefined responses based on content.
  """
  @impl true
  def analyze_pii(text) do
    cond do
      # Check for email pattern
      String.match?(text, ~r/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}/) ->
        {:ok,
         %{
           has_pii: true,
           categories: ["email"],
           explanation: "Text contains an email address."
         }}

      # Check for phone number pattern (simple check)
      String.match?(text, ~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/) ->
        {:ok,
         %{
           has_pii: true,
           categories: ["phone"],
           explanation: "Text contains a phone number."
         }}

      # Check for address indicators
      String.match?(text, ~r/\d+\s+[A-Za-z\s]+(?:street|st|avenue|ave|road|rd|boulevard|blvd)/i) ->
        {:ok,
         %{
           has_pii: true,
           categories: ["address"],
           explanation: "Text contains an address."
         }}

      # Check for credit card pattern (simple check)
      String.match?(text, ~r/\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}/) ->
        {:ok,
         %{
           has_pii: true,
           categories: ["credit_card"],
           explanation: "Text contains a credit card number."
         }}

      # Default case - no PII detected
      true ->
        {:ok, %{has_pii: false, categories: [], explanation: "No PII detected."}}
    end
  end
end
