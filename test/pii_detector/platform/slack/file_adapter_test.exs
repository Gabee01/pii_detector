defmodule PIIDetector.Platform.Slack.FileAdapterTest do
  use ExUnit.Case, async: true
  import Mox

  alias PIIDetector.FileServiceMock
  alias PIIDetector.Platform.Slack.FileAdapter

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
    test "successfully processes a Slack file (image)" do
      slack_file = %{
        "url_private" => "https://slack-files.example.com/test-file.png",
        "mimetype" => "image/png",
        "name" => "test-image.png"
      }

      expected_result = %{
        data: "base64_encoded_data",
        mimetype: "image/png",
        name: "test-image.png"
      }

      # Set up the mock to use prepare_file
      FileServiceMock
      |> expect(:prepare_file, fn file, _opts ->
        assert file["url"] == "https://slack-files.example.com/test-file.png"
        assert file["mimetype"] == "image/png"
        assert file["name"] == "test-image.png"

        # Verify the headers include the auth token
        [{"Authorization", auth_value}] = file["headers"]
        assert auth_value =~ "Bearer "

        {:ok, expected_result}
      end)

      assert {:ok, result} = FileAdapter.process_file(slack_file)
      assert result == expected_result
    end

    test "successfully processes a Slack file (pdf)" do
      slack_file = %{
        "url_private" => "https://slack-files.example.com/test-file.pdf",
        "mimetype" => "application/pdf",
        "name" => "test-doc.pdf"
      }

      expected_result = %{
        data: "base64_encoded_pdf_data",
        mimetype: "application/pdf",
        name: "test-doc.pdf"
      }

      # Set up the mock to use prepare_file
      FileServiceMock
      |> expect(:prepare_file, fn file, _opts ->
        assert file["url"] == "https://slack-files.example.com/test-file.pdf"
        assert file["mimetype"] == "application/pdf"
        assert file["name"] == "test-doc.pdf"

        {:ok, expected_result}
      end)

      assert {:ok, result} = FileAdapter.process_file(slack_file)
      assert result == expected_result
    end

    test "successfully processes any file type" do
      slack_file = %{
        "url_private" => "https://slack-files.example.com/test-file.txt",
        "mimetype" => "text/plain",
        "name" => "test.txt"
      }

      expected_result = %{
        data: "base64_encoded_text_data",
        mimetype: "text/plain",
        name: "test.txt"
      }

      # Set up the mock to use prepare_file
      FileServiceMock
      |> expect(:prepare_file, fn file, _opts ->
        assert file["url"] == "https://slack-files.example.com/test-file.txt"
        assert file["mimetype"] == "text/plain"
        assert file["name"] == "test.txt"

        {:ok, expected_result}
      end)

      assert {:ok, result} = FileAdapter.process_file(slack_file)
      assert result == expected_result
    end

    test "handles invalid file object" do
      assert {:error, message} = FileAdapter.process_file(%{"name" => "invalid.jpg"})
      assert message =~ "Invalid Slack file object format"
    end

    test "passes custom token" do
      slack_file = %{
        "url_private" => "https://slack-files.example.com/test-file.png",
        "mimetype" => "image/png",
        "name" => "test-image.png"
      }

      # Set up the mock to verify custom token with prepare_file
      FileServiceMock
      |> expect(:prepare_file, fn file, _opts ->
        [{"Authorization", auth_value}] = file["headers"]
        assert auth_value == "Bearer custom-test-token"

        {:ok, %{data: "base64data", mimetype: "image/png", name: "test.png"}}
      end)

      # Pass a custom token
      custom_token = "custom-test-token"
      assert {:ok, _result} = FileAdapter.process_file(slack_file, token: custom_token)
    end
  end
end
