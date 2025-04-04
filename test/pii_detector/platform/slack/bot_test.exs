defmodule PIIDetector.Platform.Slack.BotTest do
  use ExUnit.Case
  import Mox
  alias PIIDetector.Platform.Slack.Bot

  setup :verify_on_exit!

  describe "handle_event/3" do
    test "ignores messages with subtype" do
      result = Bot.handle_event("message", %{"subtype" => "message_changed"}, %{})
      assert result == :ok
    end

    test "ignores bot messages" do
      result = Bot.handle_event("message", %{"bot_id" => "B123456"}, %{})
      assert result == :ok
    end

    test "handles regular messages" do
      message = %{
        "channel" => "C123456",
        "user" => "U123456",
        "ts" => "1234567890.123456",
        "text" => "Hello world"
      }

      result = Bot.handle_event("message", message, %{})
      assert result == :ok
    end

    test "handles unrecognized events" do
      result = Bot.handle_event("unknown_event", %{}, %{})
      assert result == :ok
    end
  end
end
