defmodule PIIDetector.FileDownloaderTest do
  use ExUnit.Case, async: true
  import Mox

  alias PIIDetector.FileDownloader

  setup :verify_on_exit!

  describe "download_file/2" do
    test "successfully downloads a file" do
      # Regular implementation test with real Req client
      # Note: This is an integration test that can be skipped with @tag :external
      # based on your CI/CD setup
      file = %{
        "url_private" => "https://example.com/success.jpg",
        "token" => "test-token"
      }

      # Use an adapter pattern for the HTTP client in the options
      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "fake_image_data"}}
      end

      assert {:ok, "fake_image_data"} = FileDownloader.download_file(file, req_module: mock_req)
    end

    test "handles download errors" do
      file = %{
        "url_private" => "https://example.com/error.jpg",
        "token" => "test-token"
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 403, body: "Access denied"}}
      end

      assert {:error, "Failed to download file, status: 403"} =
        FileDownloader.download_file(file, req_module: mock_req)
    end

    test "handles invalid file object" do
      file = %{"name" => "invalid.jpg"}
      assert {:error, "Invalid file object, missing url_private"} = FileDownloader.download_file(file)
    end
  end

  describe "process_image/2" do
    test "successfully processes an image file" do
      file = %{
        "name" => "test_image.jpg",
        "mimetype" => "image/jpeg",
        "url_private" => "https://example.com/success.jpg",
        "token" => "test-token"
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "fake_image_data"}}
      end

      assert {:ok, processed} = FileDownloader.process_image(file, req_module: mock_req)
      assert processed.mimetype == "image/jpeg"
      assert processed.name == "test_image.jpg"
      assert processed.data == Base.encode64("fake_image_data")
    end

    test "handles unnamed image file" do
      file = %{
        "mimetype" => "image/jpeg",
        "url_private" => "https://example.com/success.jpg",
        "token" => "test-token"
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "fake_image_data"}}
      end

      assert {:ok, processed} = FileDownloader.process_image(file, req_module: mock_req)
      assert processed.name == "unnamed"
    end
  end

  describe "process_pdf/2" do
    test "successfully processes a PDF file" do
      file = %{
        "name" => "test_document.pdf",
        "mimetype" => "application/pdf",
        "url_private" => "https://example.com/pdf_file.pdf",
        "token" => "test-token"
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "fake_pdf_data"}}
      end

      assert {:ok, processed} = FileDownloader.process_pdf(file, req_module: mock_req)
      assert processed.mimetype == "application/pdf"
      assert processed.name == "test_document.pdf"
      assert processed.data == Base.encode64("fake_pdf_data")
    end
  end
end
