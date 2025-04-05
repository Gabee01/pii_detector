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

    test "handles redirect to another URL" do
      file = %{
        "url_private" => "https://example.com/redirecting.jpg",
        "token" => "test-token"
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
               FileDownloader.download_file(file, req_module: mock_req)

      # Verify the redirect was followed
      assert_received {:redirect_followed, "https://example.com/actual.jpg"}
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

      assert {:error, "Download failed"} =
               FileDownloader.process_image(file, req_module: mock_req)
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

    test "handles unnamed PDF file" do
      file = %{
        "mimetype" => "application/pdf",
        "url_private" => "https://example.com/pdf_file.pdf",
        "token" => "test-token"
      }

      mock_req = fn _url, _opts ->
        {:ok, %{status: 200, body: "fake_pdf_data"}}
      end

      assert {:ok, processed} = FileDownloader.process_pdf(file, req_module: mock_req)
      assert processed.mimetype == "application/pdf"
      assert processed.name == "unnamed"
      assert processed.data == Base.encode64("fake_pdf_data")
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
