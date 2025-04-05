defmodule PIIDetector.Platform.Notion.FileAdapterTest do
  use ExUnit.Case, async: true
  import Mox

  alias PIIDetector.FileServiceMock
  alias PIIDetector.Platform.Notion.FileAdapter

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

      # Set up the mock
      FileServiceMock
      |> expect(:process_image, fn file, _opts ->
        assert file["url"] ==
                 "https://s3.us-west-2.amazonaws.com/secure.notion-static.com/test-file.png"

        assert file["mimetype"] == "image/png"
        assert file["name"] == "test-file.png"
        assert is_list(file["headers"])
        {:ok, expected_result}
      end)

      assert {:ok, result} = FileAdapter.process_file(notion_file)
      assert result == expected_result
    end

    test "processes Notion-hosted file object (pdf)" do
      notion_file = %{
        "type" => "file",
        "file" => %{
          "url" => "https://s3.us-west-2.amazonaws.com/secure.notion-static.com/test-file.pdf",
          "expiry_time" => "2023-01-01T00:00:00.000Z"
        }
      }

      expected_result = %{
        data: "base64_encoded_data",
        mimetype: "application/pdf",
        name: "test-file.pdf"
      }

      # Set up the mock
      FileServiceMock
      |> expect(:process_pdf, fn file, _opts ->
        assert file["url"] ==
                 "https://s3.us-west-2.amazonaws.com/secure.notion-static.com/test-file.pdf"

        assert file["mimetype"] == "application/pdf"
        assert file["name"] == "test-file.pdf"
        assert is_list(file["headers"])
        {:ok, expected_result}
      end)

      assert {:ok, result} = FileAdapter.process_file(notion_file)
      assert result == expected_result
    end

    test "processes external file object (image)" do
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

      # Set up the mock
      FileServiceMock
      |> expect(:process_image, fn file, _opts ->
        assert file["url"] == "https://example.com/image.jpg"
        assert file["mimetype"] == "image/jpeg"
        assert file["name"] == "image.jpg"
        assert file["headers"] == [] # No headers for external files
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

      assert {:error, message} = FileAdapter.process_file(notion_file)
      assert message =~ "Unsupported file type"
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

      # Set up the mock to simulate download error
      FileServiceMock
      |> expect(:process_image, fn _file, _opts ->
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

      # Mock the FileService to verify it gets the headers
      expect(FileServiceMock, :process_image, fn file_data, _opts ->
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

      # Mock the FileService to verify it gets the headers with the token
      expect(FileServiceMock, :process_image, fn file_data, _opts ->
        # Find the Authorization header
        auth_header = Enum.find(file_data["headers"], fn {key, _} -> key == "Authorization" end)
        assert auth_header == {"Authorization", "Bearer custom-test-token"}

        {:ok, %{data: "base64data", mimetype: "image/jpeg"}}
      end)

      # Pass a custom token
      custom_token = "custom-test-token"
      assert {:ok, _result} = FileAdapter.process_file(file_object, [token: custom_token])
    end
  end
end
