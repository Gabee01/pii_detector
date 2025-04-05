defmodule PIIDetector.AITest do
  use ExUnit.Case, async: false
  import Mox

  alias PIIDetector.AI
  alias PIIDetector.AI.AIServiceMock

  setup :verify_on_exit!

  describe "analyze_pii/1" do
    test "correctly identifies email as PII" do
      text = "My email is test@example.com, please contact me there."

      AIServiceMock
      |> expect(:analyze_pii, fn ^text ->
        {:ok, %{has_pii: true, categories: ["email"], explanation: "Email found in text."}}
      end)

      assert {:ok, result} = AI.analyze_pii(text)
      assert result.has_pii == true
      assert "email" in result.categories
    end

    test "correctly identifies phone number as PII" do
      text = "Call me at 555-123-4567 anytime."

      AIServiceMock
      |> expect(:analyze_pii, fn ^text ->
        {:ok, %{has_pii: true, categories: ["phone"], explanation: "Phone number found in text."}}
      end)

      assert {:ok, result} = AI.analyze_pii(text)
      assert result.has_pii == true
      assert "phone" in result.categories
    end

    test "correctly identifies address as PII" do
      text = "I live at 123 Main Street, Anytown, TX 12345."

      AIServiceMock
      |> expect(:analyze_pii, fn ^text ->
        {:ok, %{has_pii: true, categories: ["address"], explanation: "Address found in text."}}
      end)

      assert {:ok, result} = AI.analyze_pii(text)
      assert result.has_pii == true
      assert "address" in result.categories
    end

    test "correctly identifies credit card as PII" do
      text = "My card number is 4111 1111 1111 1111."

      AIServiceMock
      |> expect(:analyze_pii, fn ^text ->
        {:ok,
         %{has_pii: true, categories: ["credit_card"], explanation: "Credit card found in text."}}
      end)

      assert {:ok, result} = AI.analyze_pii(text)
      assert result.has_pii == true
      assert "credit_card" in result.categories
    end

    test "returns no PII for safe text" do
      text = "This is a safe text without any personal information."

      AIServiceMock
      |> expect(:analyze_pii, fn ^text ->
        {:ok, %{has_pii: false, categories: [], explanation: "No PII detected."}}
      end)

      assert {:ok, result} = AI.analyze_pii(text)
      assert result.has_pii == false
      assert result.categories == []
    end
  end

  describe "analyze_pii_multimodal/3" do
    test "correctly identifies PII in image files" do
      text = "Check out this image"

      image_data = %{
        data: Base.encode64("fake_image_data"),
        mimetype: "image/jpeg",
        name: "test_image.jpg"
      }

      AIServiceMock
      |> expect(:analyze_pii_multimodal, fn ^text, ^image_data, nil ->
        {:ok, %{has_pii: true, categories: ["id_card"], explanation: "ID card found in image."}}
      end)

      assert {:ok, result} = AI.analyze_pii_multimodal(text, image_data, nil)
      assert result.has_pii == true
      assert "id_card" in result.categories
    end

    test "correctly identifies PII in PDF files" do
      text = "Check out this PDF"

      pdf_data = %{
        data: Base.encode64("fake_pdf_data"),
        mimetype: "application/pdf",
        name: "test_document.pdf"
      }

      AIServiceMock
      |> expect(:analyze_pii_multimodal, fn ^text, nil, ^pdf_data ->
        {:ok,
         %{has_pii: true, categories: ["financial"], explanation: "Financial data found in PDF."}}
      end)

      assert {:ok, result} = AI.analyze_pii_multimodal(text, nil, pdf_data)
      assert result.has_pii == true
      assert "financial" in result.categories
    end
  end
end
