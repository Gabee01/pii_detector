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

  describe "process_image/2" do
    test "successfully processes an image file" do
      file = %{
        "url" => "https://example.com/success.jpg",
        "mimetype" => "image/jpeg",
        "name" => "test_image.jpg",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "fake_image_data"}}
      end

      assert {:ok, processed} = Processor.process_image(file, req_module: mock_req)
      assert processed.mimetype == "image/jpeg"
      assert processed.name == "test_image.jpg"
      assert processed.data == Base.encode64("fake_image_data")
    end

    test "handles unnamed image file" do
      file = %{
        "url" => "https://example.com/success.jpg",
        "mimetype" => "image/jpeg",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "fake_image_data"}}
      end

      assert {:ok, processed} = Processor.process_image(file, req_module: mock_req)
      assert processed.name == "unnamed"
    end

    test "handles download error in process_image" do
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
               Processor.process_image(file, req_module: mock_req)
    end
  end

  describe "process_pdf/2" do
    test "successfully processes a PDF file" do
      file = %{
        "url" => "https://example.com/document.pdf",
        "mimetype" => "application/pdf",
        "name" => "test_doc.pdf",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "fake_pdf_data"}}
      end

      assert {:ok, processed} = Processor.process_pdf(file, req_module: mock_req)
      assert processed.mimetype == "application/pdf"
      assert processed.name == "test_doc.pdf"
      assert processed.data == Base.encode64("fake_pdf_data")
    end

    test "handles unnamed PDF file" do
      file = %{
        "url" => "https://example.com/document.pdf",
        "mimetype" => "application/pdf",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "fake_pdf_data"}}
      end

      assert {:ok, processed} = Processor.process_pdf(file, req_module: mock_req)
      assert processed.name == "unnamed"
    end

    test "handles download error in process_pdf" do
      file = %{
        "url" => "https://example.com/error.pdf",
        "mimetype" => "application/pdf",
        "name" => "test_doc.pdf",
        "headers" => [{"Authorization", "Bearer test-token"}]
      }

      mock_req = fn _url, _opts ->
        {:error, "Download failed"}
      end

      assert {:error, "Download failed"} =
               Processor.process_pdf(file, req_module: mock_req)
    end
  end
end
