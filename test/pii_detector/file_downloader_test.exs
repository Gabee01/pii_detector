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

      assert {:error, "Invalid file object, missing url_private"} =
               FileDownloader.download_file(file)
    end

    test "handles request error" do
      file = %{
        "url_private" => "https://example.com/error.jpg",
        "token" => "test-token"
      }

      mock_req = fn _url, _opts ->
        {:error, "Connection refused"}
      end

      assert {:error, "Connection refused"} =
               FileDownloader.download_file(file, req_module: mock_req)
    end

    test "uses token from environment when not provided in file" do
      original_token = System.get_env("SLACK_BOT_TOKEN")
      System.put_env("SLACK_BOT_TOKEN", "env-test-token")

      on_exit(fn ->
        if original_token do
          System.put_env("SLACK_BOT_TOKEN", original_token)
        else
          System.delete_env("SLACK_BOT_TOKEN")
        end
      end)

      file = %{
        "url_private" => "https://example.com/success.jpg"
        # No token in file
      }

      # Custom mock for this test case to verify the token
      mock_req = fn url, opts ->
        # Extract the token from the Authorization header
        [{"Authorization", "Bearer " <> token}] = Keyword.get(opts, :headers)
        assert token == "env-test-token"
        assert url == "https://example.com/success.jpg"

        {:ok, %{status: 200, body: "fake_image_data"}}
      end

      assert {:ok, "fake_image_data"} = FileDownloader.download_file(file, req_module: mock_req)
    end

    # Create a fake module that implements the functions needed for the FileDownloader
    defmodule MockReqModule do
      def get(url, opts) do
        # Pass the args to a function stored in the test process dictionary
        test_pid = Process.get(:test_pid)
        send(test_pid, {:get_called, url, opts})

        result = Process.get(:mock_result)
        result
      end
    end

    test "works with module-style req_module" do
      file = %{
        "url_private" => "https://example.com/success.jpg",
        "token" => "test-token"
      }

      # Store the test PID and expected result in the process dictionary
      Process.put(:test_pid, self())
      Process.put(:mock_result, {:ok, %{status: 200, body: "fake_module_data"}})

      result = FileDownloader.download_file(file, req_module: MockReqModule)

      # Verify the mock was called with the expected args
      assert_received {:get_called, url, opts}
      assert url == "https://example.com/success.jpg"
      [{"Authorization", "Bearer " <> token}] = Keyword.get(opts, :headers)
      assert token == "test-token"

      # Verify the result
      assert result == {:ok, "fake_module_data"}
    end

    test "handles error with module-style req_module" do
      file = %{
        "url_private" => "https://example.com/error.jpg",
        "token" => "test-token"
      }

      # Store the expected result in the process dictionary for the mock
      Process.put(:test_pid, self())
      Process.put(:mock_result, {:ok, %{status: 500, body: "Internal server error"}})

      result = FileDownloader.download_file(file, req_module: MockReqModule)

      # Verify the result
      assert result == {:error, "Failed to download file, status: 500"}
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

      # Create a minimal valid JPEG file data
      # JPEG files start with the marker bytes FF D8
      jpeg_signature = <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01>>
      valid_jpeg_data = jpeg_signature <> "fake_image_data"

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: valid_jpeg_data}}
      end

      assert {:ok, processed} = FileDownloader.process_image(file, req_module: mock_req)
      assert processed.mimetype == "image/jpeg"
      assert processed.name == "test_image.jpg"
      assert processed.data == Base.encode64(valid_jpeg_data)
    end

    test "handles unnamed image file" do
      file = %{
        "mimetype" => "image/jpeg",
        "url_private" => "https://example.com/success.jpg",
        "token" => "test-token"
      }

      # Create a minimal valid JPEG file data
      jpeg_signature = <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01>>
      valid_jpeg_data = jpeg_signature <> "fake_image_data"

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: valid_jpeg_data}}
      end

      assert {:ok, processed} = FileDownloader.process_image(file, req_module: mock_req)
      assert processed.name == "unnamed"
    end

    test "rejects invalid image format" do
      file = %{
        "name" => "test_image.jpg",
        "mimetype" => "image/jpeg",
        "url_private" => "https://example.com/invalid.jpg",
        "token" => "test-token"
      }

      # Data that doesn't have a JPEG signature
      invalid_data = "this is not a valid JPEG image"

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: invalid_data}}
      end

      assert {:error, "Invalid image format"} = FileDownloader.process_image(file, req_module: mock_req)
    end

    test "rejects unsupported image type" do
      file = %{
        "name" => "test_image.tiff",
        "mimetype" => "image/tiff", # Not in supported list
        "url_private" => "https://example.com/image.tiff",
        "token" => "test-token"
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "tiff data"}}
      end

      assert {:error, "Unsupported image type: image/tiff"} = FileDownloader.process_image(file, req_module: mock_req)
    end

    test "handles download error in process_image" do
      file = %{
        "name" => "test_image.jpg",
        "mimetype" => "image/jpeg",
        "url_private" => "https://example.com/error.jpg",
        "token" => "test-token"
      }

      mock_req = fn _url, _opts ->
        {:error, "Download failed"}
      end

      assert {:error, "Download failed"} = FileDownloader.process_image(file, req_module: mock_req)
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

      # Create sample PDF data with valid signature
      pdf_signature = "%PDF-1.5\n"
      valid_pdf_data = pdf_signature <> "fake_pdf_content"

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: valid_pdf_data}}
      end

      assert {:ok, processed} = FileDownloader.process_pdf(file, req_module: mock_req)
      assert processed.mimetype == "application/pdf"
      assert processed.name == "test_document.pdf"
      assert processed.data == Base.encode64(valid_pdf_data)
    end

    test "handles unnamed PDF file" do
      file = %{
        "mimetype" => "application/pdf",
        "url_private" => "https://example.com/pdf_file.pdf",
        "token" => "test-token"
      }

      # Create sample PDF data with valid signature
      pdf_signature = "%PDF-1.5\n"
      valid_pdf_data = pdf_signature <> "fake_pdf_content"

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: valid_pdf_data}}
      end

      assert {:ok, processed} = FileDownloader.process_pdf(file, req_module: mock_req)
      assert processed.mimetype == "application/pdf"
      assert processed.name == "unnamed"
      assert processed.data == Base.encode64(valid_pdf_data)
    end

    test "rejects invalid PDF format" do
      file = %{
        "name" => "test_document.pdf",
        "mimetype" => "application/pdf",
        "url_private" => "https://example.com/invalid.pdf",
        "token" => "test-token"
      }

      # Data that doesn't have a PDF signature
      invalid_data = "this is not a valid PDF document"

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: invalid_data}}
      end

      assert {:error, "Invalid PDF format"} = FileDownloader.process_pdf(file, req_module: mock_req)
    end

    test "handles download error in process_pdf" do
      file = %{
        "name" => "test_document.pdf",
        "mimetype" => "application/pdf",
        "url_private" => "https://example.com/error.pdf",
        "token" => "test-token"
      }

      mock_req = fn _url, _opts ->
        {:error, "Download failed"}
      end

      assert {:error, "Download failed"} = FileDownloader.process_pdf(file, req_module: mock_req)
    end
  end
end
