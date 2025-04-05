defmodule PIIDetector.Platform.Notion.FileAdapterTest do
  use ExUnit.Case, async: true
  import Mox

  alias PIIDetector.Platform.Notion.FileAdapter
  alias PIIDetector.FileServiceMock

  # We need to make the module linked to the test process
  setup :set_mox_from_context
  setup :verify_on_exit!

  # Set up application environment for testing
  setup do
    # Store the current value
    current_file_service = Application.get_env(:pii_detector, :file_service)

    # Set the mock for our tests
    Application.put_env(:pii_detector, :file_service, FileServiceMock)

    # Clean up after tests
    on_exit(fn ->
      Application.put_env(:pii_detector, :file_service, current_file_service)
    end)

    :ok
  end

  describe "process_file/2" do
    test "processes Notion-hosted file object (image)" do
      notion_file = %{
        "type" => "file",
        "file" => %{
          "url" => "https://s3.us-west-2.amazonaws.com/secure.notion-static.com/test-file.png",
          "expiry_time" => "2023-01-01T00:00:00.000Z"
        }
      }

      expected_result = %{
        data: "base64_encoded_data",
        mimetype: "image/png",
        name: "test-file.png"
      }

      # Set up the mock to use process_generic_file instead
      FileServiceMock
      |> expect(:process_generic_file, fn file, _opts ->
        assert file["url"] == "https://s3.us-west-2.amazonaws.com/secure.notion-static.com/test-file.png"
        assert file["mimetype"] == "image/png"
        assert file["name"] == "test-file.png"
        # Headers should now be present
        assert is_list(file["headers"])

        # The URL doesn't have X-Amz- parameter so it's not detected as pre-signed, auth header present
        assert Enum.any?(file["headers"], fn {key, _} -> key == "Authorization" end)

        # User-Agent should be present
        assert Enum.any?(file["headers"], fn {key, _} -> key == "User-Agent" end)

        {:ok, expected_result}
      end)

      assert {:ok, result} = FileAdapter.process_file(notion_file)
      assert result == expected_result
    end

    test "processes externally hosted file object (PDF)" do
      notion_file = %{
        "type" => "external",
        "external" => %{
          "url" => "https://example.com/document.pdf"
        }
      }

      expected_result = %{
        data: "base64_encoded_data",
        mimetype: "application/pdf",
        name: "document.pdf"
      }

      # Set up the mock to use process_generic_file instead
      FileServiceMock
      |> expect(:process_generic_file, fn file, _opts ->
        assert file["url"] == "https://example.com/document.pdf"
        assert file["mimetype"] == "application/pdf"
        assert file["name"] == "document.pdf"
        # Headers should be present for external files too
        assert is_list(file["headers"])
        # For non-S3 URLs, authorization should be included
        assert Enum.any?(file["headers"], fn {key, _} -> key == "Authorization" end)

        {:ok, expected_result}
      end)

      assert {:ok, result} = FileAdapter.process_file(notion_file)
      assert result == expected_result
    end

    test "processes external image file" do
      notion_file = %{
        "type" => "external",
        "external" => %{
          "url" => "https://example.com/image.jpg"
        }
      }

      expected_result = %{
        data: "base64_encoded_data",
        mimetype: "image/jpeg",
        name: "image.jpg"
      }

      # Set up the mock to use process_generic_file instead
      FileServiceMock
      |> expect(:process_generic_file, fn file, _opts ->
        assert file["url"] == "https://example.com/image.jpg"
        assert file["mimetype"] == "image/jpeg"
        assert file["name"] == "image.jpg"
        # Headers should now be present for external files
        assert is_list(file["headers"])
        # For non-S3 URLs, authorization should be included
        assert Enum.any?(file["headers"], fn {key, _} -> key == "Authorization" end)
        {:ok, expected_result}
      end)

      assert {:ok, result} = FileAdapter.process_file(notion_file)
      assert result == expected_result
    end

    test "handles unsupported file type" do
      notion_file = %{
        "type" => "file",
        "file" => %{
          "url" => "https://s3.us-west-2.amazonaws.com/secure.notion-static.com/test-file.txt",
          "expiry_time" => "2023-01-01T00:00:00.000Z"
        }
      }

      # Now we should be able to process any file format
      FileServiceMock
      |> expect(:process_generic_file, fn file, _opts ->
        assert file["mimetype"] == "text/plain"
        assert file["name"] == "test-file.txt"
        {:ok, %{data: "base64_data", mimetype: "text/plain", name: "test-file.txt"}}
      end)

      assert {:ok, _result} = FileAdapter.process_file(notion_file)
    end

    test "handles invalid file object structure" do
      assert {:error, message} = FileAdapter.process_file(%{"type" => "unknown"})
      assert message =~ "Unsupported file object format"

      assert {:error, message} = FileAdapter.process_file(%{"type" => "file", "file" => %{}})
      assert message =~ "Invalid Notion file object structure"

      assert {:error, message} =
               FileAdapter.process_file(%{"type" => "external", "external" => %{}})

      assert message =~ "Invalid external file object structure"
    end

    test "handles file download errors" do
      notion_file = %{
        "type" => "file",
        "file" => %{
          "url" => "https://s3.us-west-2.amazonaws.com/secure.notion-static.com/test-file.png",
          "expiry_time" => "2023-01-01T00:00:00.000Z"
        }
      }

      error_message = "Download failed: connection error"

      # Set up the mock to simulate download error with process_generic_file
      FileServiceMock
      |> expect(:process_generic_file, fn _file, _opts ->
        {:error, error_message}
      end)

      assert {:error, message} = FileAdapter.process_file(notion_file)
      assert message == error_message
    end

    test "process_file/2 correctly includes headers for Notion-hosted file object (image)" do
      file_object = %{
        "type" => "file",
        "file" => %{
          "url" => "https://notion-s3-media.example.com/test.jpg"
        }
      }

      # Mock the FileService to verify it gets the headers using process_generic_file
      expect(FileServiceMock, :process_generic_file, fn file_data, _opts ->
        # Verify the headers were included
        assert is_list(file_data["headers"])
        assert Enum.any?(file_data["headers"], fn {key, _} -> key == "Authorization" end)
        assert Enum.any?(file_data["headers"], fn {key, _} -> key == "User-Agent" end)

        {:ok, %{data: "base64data", mimetype: "image/jpeg"}}
      end)

      assert {:ok, _result} = FileAdapter.process_file(file_object)
    end

    test "process_file/2 passes custom token to build headers" do
      file_object = %{
        "type" => "file",
        "file" => %{
          "url" => "https://notion-s3-media.example.com/test.jpg"
        }
      }

      # Mock the FileService to verify it gets the headers with the token using process_generic_file
      expect(FileServiceMock, :process_generic_file, fn file_data, _opts ->
        # Find the Authorization header
        auth_header = Enum.find(file_data["headers"], fn {key, _} -> key == "Authorization" end)
        assert auth_header == {"Authorization", "Bearer custom-test-token"}

        {:ok, %{data: "base64data", mimetype: "image/jpeg"}}
      end)

      # Pass a custom token
      custom_token = "custom-test-token"
      assert {:ok, _result} = FileAdapter.process_file(file_object, token: custom_token)
    end

    test "process_file/2 doesn't include authorization headers for AWS S3 pre-signed URLs" do
      # Create a file object with an AWS S3 pre-signed URL
      file_object = %{
        "type" => "file",
        "file" => %{
          "url" => "https://prod-files-secure.s3.us-west-2.amazonaws.com/12345/file.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIA..."
        }
      }

      # Mock the FileService to verify no authorization headers are included using process_generic_file
      expect(FileServiceMock, :process_generic_file, fn file_data, _opts ->
        # Check that there is no Authorization header
        auth_header = Enum.find(file_data["headers"], fn {key, _} -> key == "Authorization" end)
        assert auth_header == nil

        # But should still have User-Agent and Accept headers
        assert Enum.any?(file_data["headers"], fn {key, _} -> key == "User-Agent" end)
        assert Enum.any?(file_data["headers"], fn {key, _} -> key == "Accept" end)

        {:ok, %{data: "base64data", mimetype: "image/png"}}
      end)

      assert {:ok, _result} = FileAdapter.process_file(file_object)
    end

    test "process_file/2 includes authorization headers for non-S3 URLs" do
      # Create a file object with a regular URL
      file_object = %{
        "type" => "file",
        "file" => %{
          "url" => "https://notion.so/api/v1/files/123456/image.png"
        }
      }

      # Mock the FileService to verify authorization headers are included using process_generic_file
      expect(FileServiceMock, :process_generic_file, fn file_data, _opts ->
        # Check that there is an Authorization header
        auth_header = Enum.find(file_data["headers"], fn {key, _} -> key == "Authorization" end)
        assert auth_header != nil

        {:ok, %{data: "base64data", mimetype: "image/png"}}
      end)

      assert {:ok, _result} = FileAdapter.process_file(file_object)
    end
  end
end
