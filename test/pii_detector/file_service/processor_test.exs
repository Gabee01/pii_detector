defmodule PIIDetector.FileService.ProcessorTest do
  use ExUnit.Case, async: true

  alias PIIDetector.FileService.Processor

  describe "download_file/2" do
    test "successfully downloads a file" do
      file = %{
        "url" => "https://example.com/success.jpg",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      # Use an adapter pattern for the HTTP client in the options
      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "fake_image_data"}}
      end

      assert {:ok, "fake_image_data"} = Processor.download_file(file, req_module: mock_req)
    end

    test "handles download errors" do
      file = %{
        "url" => "https://example.com/error.jpg",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 403, body: "Access denied"}}
      end

      assert {:error, "Failed to download file, status: 403"} =
               Processor.download_file(file, req_module: mock_req)
    end

    test "handles request error" do
      file = %{
        "url" => "https://example.com/error.jpg",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      mock_req = fn _url, _opts ->
        {:error, "Connection refused"}
      end

      assert {:error, "Connection refused"} =
               Processor.download_file(file, req_module: mock_req)
    end

    test "handles redirect to another URL" do
      file = %{
        "url" => "https://example.com/redirecting.jpg",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      # Create a stateful mock that returns a redirect first, then success
      test_pid = self()

      mock_req = fn url, _opts ->
        if url == "https://example.com/redirecting.jpg" do
          {:ok,
           %{
             status: 302,
             headers: [{"Location", "https://example.com/actual.jpg"}],
             body: "Redirecting..."
           }}
        else
          send(test_pid, {:redirect_followed, url})
          {:ok, %{status: 200, body: "real_image_data"}}
        end
      end

      assert {:ok, "real_image_data"} =
               Processor.download_file(file, req_module: mock_req)

      # Verify the redirect was followed
      assert_received {:redirect_followed, "https://example.com/actual.jpg"}
    end

    test "handles download errors when receiving HTML instead of file content" do
      file = %{
        "url" => "https://example.com/html_file.jpg",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      # Mock a response that returns HTML instead of a binary file
      mock_req = fn _url, _opts ->
        html_content = """
        <!DOCTYPE html>
        <html>
          <head><title>Example HTML</title></head>
          <body>This is not an image file</body>
        </html>
        """

        {:ok, %{status: 200, body: html_content}}
      end

      assert {:error, "Download failed: received HTML instead of file data"} =
               Processor.download_file(file, req_module: mock_req)
    end
  end

  describe "prepare_file/2" do
    test "successfully prepares an image file" do
      file = %{
        "url" => "https://example.com/success.jpg",
        "mimetype" => "image/jpeg",
        "name" => "test_image.jpg",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "fake_image_data"}}
      end

      assert {:ok, processed} = Processor.prepare_file(file, req_module: mock_req)
      assert processed.mimetype == "image/jpeg"
      assert processed.name == "test_image.jpg"
      assert processed.data == Base.encode64("fake_image_data")
    end

    test "successfully prepares a PDF file" do
      file = %{
        "url" => "https://example.com/document.pdf",
        "mimetype" => "application/pdf",
        "name" => "test_doc.pdf",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "fake_pdf_data"}}
      end

      assert {:ok, processed} = Processor.prepare_file(file, req_module: mock_req)
      assert processed.mimetype == "application/pdf"
      assert processed.name == "test_doc.pdf"
      assert processed.data == Base.encode64("fake_pdf_data")
    end

    test "successfully prepares any file type" do
      file = %{
        "url" => "https://example.com/document.txt",
        "mimetype" => "text/plain",
        "name" => "test.txt",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "This is a text file content"}}
      end

      assert {:ok, processed} = Processor.prepare_file(file, req_module: mock_req)
      assert processed.mimetype == "text/plain"
      assert processed.name == "test.txt"
      assert processed.data == Base.encode64("This is a text file content")
    end

    test "handles unnamed file" do
      file = %{
        "url" => "https://example.com/document.pdf",
        "mimetype" => "application/pdf",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "fake_pdf_data"}}
      end

      assert {:ok, processed} = Processor.prepare_file(file, req_module: mock_req)
      assert processed.name == "unnamed"
    end

    test "handles unknown mimetype" do
      file = %{
        "url" => "https://example.com/file.bin",
        "name" => "unknown.bin",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "binary_data"}}
      end

      assert {:ok, processed} = Processor.prepare_file(file, req_module: mock_req)
      assert processed.mimetype == "application/octet-stream"
      assert processed.name == "unknown.bin"
    end

    test "handles download error" do
      file = %{
        "url" => "https://example.com/error.jpg",
        "mimetype" => "image/jpeg",
        "name" => "test_image.jpg",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      mock_req = fn _url, _opts ->
        {:error, "Download failed"}
      end

      assert {:error, "Download failed"} =
               Processor.prepare_file(file, req_module: mock_req)
    end

    test "handles invalid file object" do
      file = %{"name" => "invalid.jpg"}

      assert {:error, _} = Processor.prepare_file(file)
    end
  end
end
