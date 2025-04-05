defmodule PIIDetector.Detector.ContentProcessorTest do
  use ExUnit.Case, async: false
  import Mox

  alias PIIDetector.Detector.ContentProcessor
  alias PIIDetector.FileDownloaderMock

  # Ensure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "extract_full_content/1" do
    test "extracts text from content" do
      content = %{
        text: "This is a message",
        files: [],
        attachments: []
      }

      assert ContentProcessor.extract_full_content(content) == "This is a message\n\n"
    end

    test "handles nil text" do
      content = %{
        text: nil,
        files: [],
        attachments: []
      }

      assert ContentProcessor.extract_full_content(content) == "\n\n"
    end

    test "extracts text from attachments" do
      content = %{
        text: "Main message",
        files: [],
        attachments: [%{"text" => "Attachment text"}]
      }

      assert ContentProcessor.extract_full_content(content) == "Main message\nAttachment text\n"
    end

    test "handles multiple attachments" do
      content = %{
        text: "Main message",
        files: [],
        attachments: [
          %{"text" => "Attachment 1"},
          %{"text" => "Attachment 2"},
          %{"other" => "Not text"} # Should be ignored
        ]
      }

      assert ContentProcessor.extract_full_content(content) == "Main message\nAttachment 1\nAttachment 2\n"
    end

    test "extracts file descriptions" do
      content = %{
        text: "Check these files",
        files: [
          %{"mimetype" => "image/jpeg", "name" => "image1.jpg"},
          %{"mimetype" => "application/pdf", "name" => "document.pdf"},
          %{"mimetype" => "text/plain", "name" => "text.txt"} # Should be ignored
        ],
        attachments: []
      }

      expected = "Check these files\n\nImage file: image1.jpg\nPDF file: document.pdf\n"
      assert ContentProcessor.extract_full_content(content) == expected
    end

    test "handles unnamed files" do
      content = %{
        text: "Check this file",
        files: [%{"mimetype" => "image/jpeg"}],
        attachments: []
      }

      assert ContentProcessor.extract_full_content(content) == "Check this file\n\nImage file: unnamed\n"
    end

    test "combines all content types" do
      content = %{
        text: "Main text",
        files: [%{"mimetype" => "image/jpeg", "name" => "photo.jpg"}],
        attachments: [%{"text" => "Attachment info"}]
      }

      expected = "Main text\nAttachment info\nImage file: photo.jpg\n"
      assert ContentProcessor.extract_full_content(content) == expected
    end
  end

  describe "process_files_for_multimodal/1" do
    test "processes image files correctly" do
      # Set up expectations for FileDownloader
      FileDownloaderMock
      |> expect(:process_image, fn file, _opts ->
        assert file["name"] == "test_image.jpg"
        assert file["mimetype"] == "image/jpeg"

        {:ok, %{data: "base64_data", mimetype: "image/jpeg", name: "test_image.jpg"}}
      end)

      files = [
        %{
          "name" => "test_image.jpg",
          "mimetype" => "image/jpeg",
          "url_private" => "https://example.com/test_image.jpg",
          "token" => "test-token"
        }
      ]

      {image_data, pdf_data} = ContentProcessor.process_files_for_multimodal(files)

      assert image_data != nil
      assert image_data.name == "test_image.jpg"
      assert image_data.mimetype == "image/jpeg"
      assert image_data.data == "base64_data"
      assert pdf_data == nil
    end

    test "processes PDF files correctly" do
      # Set up expectations for FileDownloader
      FileDownloaderMock
      |> expect(:process_pdf, fn file, _opts ->
        assert file["name"] == "test_doc.pdf"
        assert file["mimetype"] == "application/pdf"

        {:ok, %{data: "base64_pdf_data", mimetype: "application/pdf", name: "test_doc.pdf"}}
      end)

      files = [
        %{
          "name" => "test_doc.pdf",
          "mimetype" => "application/pdf",
          "url_private" => "https://example.com/test_doc.pdf",
          "token" => "test-token"
        }
      ]

      {image_data, pdf_data} = ContentProcessor.process_files_for_multimodal(files)

      assert image_data == nil
      assert pdf_data != nil
      assert pdf_data.name == "test_doc.pdf"
      assert pdf_data.mimetype == "application/pdf"
      assert pdf_data.data == "base64_pdf_data"
    end

    test "processes both image and PDF files" do
      # Set up expectations for FileDownloader
      FileDownloaderMock
      |> expect(:process_image, fn file, _opts ->
        assert file["name"] == "test_image.jpg"
        {:ok, %{data: "base64_image_data", mimetype: "image/jpeg", name: "test_image.jpg"}}
      end)
      |> expect(:process_pdf, fn file, _opts ->
        assert file["name"] == "test_doc.pdf"
        {:ok, %{data: "base64_pdf_data", mimetype: "application/pdf", name: "test_doc.pdf"}}
      end)

      files = [
        %{
          "name" => "test_image.jpg",
          "mimetype" => "image/jpeg",
          "url_private" => "https://example.com/test_image.jpg",
          "token" => "test-token"
        },
        %{
          "name" => "test_doc.pdf",
          "mimetype" => "application/pdf",
          "url_private" => "https://example.com/test_doc.pdf",
          "token" => "test-token"
        }
      ]

      {image_data, pdf_data} = ContentProcessor.process_files_for_multimodal(files)

      assert image_data != nil
      assert image_data.data == "base64_image_data"
      assert pdf_data != nil
      assert pdf_data.data == "base64_pdf_data"
    end

    test "handles processing errors gracefully" do
      # Set up expectations for FileDownloader to simulate errors
      FileDownloaderMock
      |> expect(:process_image, fn _file, _opts ->
        {:error, "Failed to download image"}
      end)

      files = [
        %{
          "name" => "error_image.jpg",
          "mimetype" => "image/jpeg",
          "url_private" => "https://example.com/error_image.jpg",
          "token" => "test-token"
        }
      ]

      {image_data, pdf_data} = ContentProcessor.process_files_for_multimodal(files)

      assert image_data == nil
      assert pdf_data == nil
    end

    test "ignores unsupported file types" do
      files = [
        %{
          "name" => "data.txt",
          "mimetype" => "text/plain",
          "url_private" => "https://example.com/data.txt",
          "token" => "test-token"
        }
      ]

      {image_data, pdf_data} = ContentProcessor.process_files_for_multimodal(files)

      assert image_data == nil
      assert pdf_data == nil
    end

    test "handles empty file list" do
      {image_data, pdf_data} = ContentProcessor.process_files_for_multimodal([])

      assert image_data == nil
      assert pdf_data == nil
    end

    test "handles nil file list" do
      {image_data, pdf_data} = ContentProcessor.process_files_for_multimodal(nil)

      assert image_data == nil
      assert pdf_data == nil
    end
  end
end
