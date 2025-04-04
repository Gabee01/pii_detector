defmodule PIIDetector.AITest do
  use PIIDetector.DataCase

  alias PIIDetector.AI

  describe "analyze_pii/1" do
    test "correctly identifies email as PII" do
      text = "My email is test@example.com, please contact me there."

      assert {:ok, result} = AI.analyze_pii(text)
      assert result.has_pii == true
      assert "email" in result.categories
    end

    test "correctly identifies phone number as PII" do
      text = "Call me at 555-123-4567 anytime."

      assert {:ok, result} = AI.analyze_pii(text)
      assert result.has_pii == true
      assert "phone" in result.categories
    end

    test "correctly identifies address as PII" do
      text = "I live at 123 Main Street, Anytown, TX 12345."

      assert {:ok, result} = AI.analyze_pii(text)
      assert result.has_pii == true
      assert "address" in result.categories
    end

    test "correctly identifies credit card as PII" do
      text = "My card number is 4111 1111 1111 1111."

      assert {:ok, result} = AI.analyze_pii(text)
      assert result.has_pii == true
      assert "credit_card" in result.categories
    end

    test "returns no PII for safe text" do
      text = "This is a safe text without any personal information."

      assert {:ok, result} = AI.analyze_pii(text)
      assert result.has_pii == false
      assert result.categories == []
    end
  end
end
