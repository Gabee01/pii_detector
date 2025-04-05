defmodule PIIDetector.DetectorTest do
  use ExUnit.Case, async: false
  import Mox

  alias PIIDetector.AI.AIServiceMock
  alias PIIDetector.Detector
  alias PIIDetector.DetectorMock
  alias PIIDetector.FileDownloaderMock

  # Ensure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "PIIDetector.Detector.detect_pii/1 (direct)" do
    test "returns false for content without PII" do
      # Set up expectation for AI service
      AIServiceMock
      |> expect(:analyze_pii, fn _text ->
        {:ok, %{has_pii: false, categories: [], explanation: "No PII detected."}}
      end)

      content = %{text: "This is a normal message", files: [], attachments: []}

      assert {:pii_detected, false, []} = Detector.detect_pii(content)
    end

    test "detects email PII in text" do
      # Set up expectation for AI service
      AIServiceMock
      |> expect(:analyze_pii, fn text ->
        assert String.contains?(text, "john.doe@example.com")

        {:ok,
         %{has_pii: true, categories: ["email"], explanation: "Text contains an email address."}}
      end)

      content = %{
        text: "Contact me at john.doe@example.com",
        files: [],
        attachments: []
      }

      assert {:pii_detected, true, categories} = Detector.detect_pii(content)
      assert "email" in categories
    end

    test "detects phone PII in text" do
      # Set up expectation for AI service
      AIServiceMock
      |> expect(:analyze_pii, fn text ->
        assert String.contains?(text, "555-123-4567")

        {:ok,
         %{has_pii: true, categories: ["phone"], explanation: "Text contains a phone number."}}
      end)

      content = %{
        text: "Call me at 555-123-4567",
        files: [],
        attachments: []
      }

      assert {:pii_detected, true, categories} = Detector.detect_pii(content)
      assert "phone" in categories
    end

    test "handles empty content" do
      # No need to set up expectations as we don't expect any calls
      content = %{text: "", files: [], attachments: []}
      assert {:pii_detected, false, []} = Detector.detect_pii(content)
    end

    test "detects PII in attachments" do
      # Set up expectation for AI service
      AIServiceMock
      |> expect(:analyze_pii, fn text ->
        assert String.contains?(text, "test@example.com")

        {:ok,
         %{has_pii: true, categories: ["email"], explanation: "Text contains an email address."}}
      end)

      content = %{
        text: "See attachment",
        files: [],
        attachments: [%{"text" => "Contact me at test@example.com"}]
      }

      assert {:pii_detected, true, categories} = Detector.detect_pii(content)
      assert "email" in categories
    end

    test "detects address PII in text" do
      # Set up expectation for AI service
      AIServiceMock
      |> expect(:analyze_pii, fn text ->
        assert String.contains?(text, "123 Main Street")
        {:ok, %{has_pii: true, categories: ["address"], explanation: "Text contains an address."}}
      end)

      content = %{
        text: "I live at 123 Main Street",
        files: [],
        attachments: []
      }

      assert {:pii_detected, true, categories} = Detector.detect_pii(content)
      assert "address" in categories
    end

    test "detects credit card PII in text" do
      # Set up expectation for AI service
      AIServiceMock
      |> expect(:analyze_pii, fn text ->
        assert String.contains?(text, "4111 1111 1111 1111")

        {:ok,
         %{
           has_pii: true,
           categories: ["credit_card"],
           explanation: "Text contains a credit card number."
         }}
      end)

      content = %{
        text: "My card number is 4111 1111 1111 1111",
        files: [],
        attachments: []
      }

      assert {:pii_detected, true, categories} = Detector.detect_pii(content)
      assert "credit_card" in categories
    end

    test "detects PII in image files" do
      # Create valid JPEG data with signature
      jpeg_signature = <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01>>
      valid_jpeg_data = jpeg_signature <> "fake_image_data"

      # Set up expectations for FileDownloader
      FileDownloaderMock
      |> expect(:process_image, fn file, _opts ->
        assert file["name"] == "pii_test_image.jpg"
        assert file["mimetype"] == "image/jpeg"

        {:ok,
         %{
           data: Base.encode64(valid_jpeg_data),
           mimetype: "image/jpeg",
           name: "pii_test_image.jpg"
         }}
      end)

      # Set up expectation for AI service
      AIServiceMock
      |> expect(:analyze_pii_multimodal, fn _text, image_data, _pdf_data ->
        assert image_data != nil
        assert image_data.name =~ "pii_test_image"
        assert image_data.mimetype =~ "image/jpeg"
        assert image_data.data == Base.encode64(valid_jpeg_data)

        {:ok,
         %{
           has_pii: true,
           categories: ["name"],
           explanation: "Image contains personal information."
         }}
      end)

      # Create a mock file with PII in the name
      image_file = %{
        "name" => "pii_test_image.jpg",
        "mimetype" => "image/jpeg",
        "url_private" => "https://example.com/pii_test_image.jpg",
        "token" => "test-token"
      }

      content = %{
        text: "Check out this image",
        files: [image_file],
        attachments: []
      }

      assert {:pii_detected, true, categories} = Detector.detect_pii(content)
      assert "name" in categories
    end

    test "detects PII in PDF files" do
      # Create valid PDF data with signature
      pdf_signature = "%PDF-1.5\n"
      valid_pdf_data = pdf_signature <> "fake_pdf_content"

      # Set up expectations for FileDownloader
      FileDownloaderMock
      |> expect(:process_pdf, fn file, _opts ->
        assert file["name"] == "pii_financial.pdf"
        assert file["mimetype"] == "application/pdf"

        {:ok,
         %{
           data: Base.encode64(valid_pdf_data),
           mimetype: "application/pdf",
           name: "pii_financial.pdf"
         }}
      end)

      # Set up expectation for AI service
      AIServiceMock
      |> expect(:analyze_pii_multimodal, fn _text, _image_data, pdf_data ->
        assert pdf_data != nil
        assert pdf_data.name =~ "pii_financial"
        assert pdf_data.mimetype == "application/pdf"
        assert pdf_data.data == Base.encode64(valid_pdf_data)

        {:ok,
         %{
           has_pii: true,
           categories: ["financial"],
           explanation: "PDF contains financial information."
         }}
      end)

      # Create a mock file with PII in the name
      pdf_file = %{
        "name" => "pii_financial.pdf",
        "mimetype" => "application/pdf",
        "url_private" => "https://example.com/pii_financial.pdf",
        "token" => "test-token"
      }

      content = %{
        text: "Check out this PDF",
        files: [pdf_file],
        attachments: []
      }

      assert {:pii_detected, true, categories} = Detector.detect_pii(content)
      assert "financial" in categories
    end

    test "handles non-PII files correctly" do
      # Set up expectations for FileDownloader
      FileDownloaderMock
      |> expect(:process_image, fn file, _opts ->
        assert file["name"] == "normal_image.jpg"
        assert file["mimetype"] == "image/jpeg"

        {:ok,
         %{
           data: Base.encode64("fake_normal_image_data"),
           mimetype: "image/jpeg",
           name: "normal_image.jpg"
         }}
      end)

      # Set up expectation for AI service
      AIServiceMock
      |> expect(:analyze_pii_multimodal, fn _text, image_data, _pdf_data ->
        assert image_data != nil
        assert image_data.name =~ "normal_image"

        {:ok, %{has_pii: false, categories: [], explanation: "No PII detected in text or files."}}
      end)

      # Create a mock file without PII in the name
      normal_file = %{
        "name" => "normal_image.jpg",
        "mimetype" => "image/jpeg",
        "url_private" => "https://example.com/normal_image.jpg",
        "token" => "test-token"
      }

      content = %{
        text: "Check out this image",
        files: [normal_file],
        attachments: []
      }

      assert {:pii_detected, false, []} = Detector.detect_pii(content)
    end
  end

  describe "PIIDetector.detect_pii/1 (delegation)" do
    test "returns false for content without PII" do
      # Set up expectation for the detector module via mock
      DetectorMock
      |> expect(:detect_pii, fn _content, _opts ->
        {:pii_detected, false, []}
      end)

      content = %{text: "This is a normal message", files: [], attachments: []}

      # Test the root context function that delegates to the detector
      assert {:pii_detected, false, []} = PIIDetector.detect_pii(content)
    end

    test "detects PII in content" do
      # Set up expectation for the detector module via mock
      DetectorMock
      |> expect(:detect_pii, fn _content, _opts ->
        {:pii_detected, true, ["email"]}
      end)

      content = %{
        text: "Contact me at john.doe@example.com",
        files: [],
        attachments: []
      }

      # Test the root context function that delegates to the detector
      assert {:pii_detected, true, categories} = PIIDetector.detect_pii(content)
      assert "email" in categories
    end
  end

  describe "detector with files" do
    test "detects PII in image files" do
      # Create valid JPEG data with signature
      jpeg_signature = <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01>>
      valid_jpeg_data = jpeg_signature <> "fake_image_data"

      # Set up expectations for FileDownloader
      FileDownloaderMock
      |> expect(:process_image, fn file, _opts ->
        assert file["name"] == "pii_test_image.jpg"
        assert file["mimetype"] == "image/jpeg"

        {:ok,
         %{
           data: Base.encode64(valid_jpeg_data),
           mimetype: "image/jpeg",
           name: "pii_test_image.jpg"
         }}
      end)

      # Set up expectation for AI service
      AIServiceMock
      |> expect(:analyze_pii_multimodal, fn _text, image_data, _pdf_data ->
        assert image_data != nil
        assert image_data.name =~ "pii_test_image"
        assert image_data.mimetype =~ "image/jpeg"
        assert image_data.data == Base.encode64(valid_jpeg_data)

        {:ok,
         %{
           has_pii: true,
           categories: ["name"],
           explanation: "Image contains personal information."
         }}
      end)

      # Create a mock file with PII in the name
      image_file = %{
        "name" => "pii_test_image.jpg",
        "mimetype" => "image/jpeg",
        "url_private" => "https://example.com/pii_test_image.jpg",
        "token" => "test-token"
      }

      content = %{
        text: "Check out this image",
        files: [image_file],
        attachments: []
      }

      assert {:pii_detected, true, categories} = Detector.detect_pii(content)
      assert "name" in categories
    end
  end
end
