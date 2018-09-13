defmodule BotKit.SingleBotTest do
  alias BotKit.{Bot, Chat, SingleMock}

  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  test "init/1 callback" do
    expect(SingleMock, :init, fn :foobar -> {:ok, %{foo: :bar}} end)

    assert {:ok, bot} = Bot.start_link(SingleMock, :foobar)
  end

  describe "sync bot" do
    test "begin_chat/1" do
      SingleMock
      |> expect(:init, fn :ok -> {:ok, %{foo: :bar}} end)
      |> expect(:enter, fn chat -> Chat.reply_with(chat, "hi") end)

      {:ok, bot} = Bot.start_link(SingleMock, :ok)
      allow(SingleMock, self(), bot)
      assert "hi" = Bot.begin(bot)
    end

    test "pipeline/1, on/2" do
      SingleMock
      |> expect(:init, fn :ok -> {:ok, %{foo: :bar}} end)
      |> expect(:pipeline, fn result -> String.downcase(result) end)
      |> expect(:enter, fn it -> it end)
      |> expect(:on, fn chat, result -> Chat.reply_with(chat, result) end)

      {:ok, bot} = Bot.start_link(SingleMock, :ok)
      allow(SingleMock, self(), bot)
      Bot.begin(bot)
      assert "foobar" = Bot.send(bot, "FOObAr")
    end
  end

  describe "async bot" do
    test "begin_chat/1" do
      SingleMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, fn chat, message -> send(chat.data, message) end)
      |> expect(:enter, fn chat -> Chat.reply_with(chat, "hi") end)

      {:ok, bot} = Bot.start_link(SingleMock, self())
      allow(SingleMock, self(), bot)
      assert :ok = Bot.begin_async(bot)
      assert_receive "hi"
    end

    test "pipeline/1, on/2" do
      SingleMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, 2, fn chat, message -> send(chat.data, message) end)
      |> expect(:pipeline, fn result -> String.downcase(result) end)
      |> expect(:enter, fn chat -> Chat.reply_with(chat, "enter") end)
      |> expect(:on, fn chat, result -> Chat.reply_with(chat, result) end)

      {:ok, bot} = Bot.start_link(SingleMock, self())
      allow(SingleMock, self(), bot)
      :ok = Bot.begin_async(bot)
      :ok = Bot.send_async(bot, "FOOBAR")
      assert_receive "enter"
      assert_receive "foobar"
    end
  end
end
