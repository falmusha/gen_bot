defmodule BotKit.MultiBotTest do
  alias BotKit.{
    Bot,
    Chat,
    MultiMock,
    MultiFooStateMock,
    MultiBarStateMock,
    MultiQuxStateMock
  }

  use ExUnit.Case
  import Mox

  @states [foo: MultiFooStateMock, bar: MultiBarStateMock, qux: MultiQuxStateMock]

  setup :verify_on_exit!

  test "init/1 callback" do
    expect(MultiMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

    assert {:ok, bot} = Bot.start_link(MultiMock, :ok, states: @states)
  end

  describe "sync bot" do
    test "begin_chat/1" do
      expect(MultiMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)
      expect(MultiFooStateMock, :enter, fn chat -> Chat.reply_with(chat, "hi") end)

      {:ok, bot} = Bot.start_link(MultiMock, :ok, states: @states)
      allow(MultiFooStateMock, self(), bot)
      assert "hi" = Bot.begin(bot)
    end

    test "state_pipeline/1, on/2" do
      expect(MultiMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

      MultiFooStateMock
      |> expect(:enter, fn chat -> chat end)
      |> expect(:on, fn chat, result -> Chat.reply_with(chat, result) end)
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)

      {:ok, bot} = Bot.start_link(MultiMock, :ok, states: @states)
      allow(MultiMock, self(), bot)
      allow(MultiFooStateMock, self(), bot)
      Bot.begin(bot)
      assert "foobar" = Bot.send(bot, "FOObAr")
    end

    test "Chat.goto/2 on enter" do
      expect(MultiMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

      expect(MultiFooStateMock, :enter, fn chat ->
        chat |> Chat.reply_with("transfering") |> Chat.goto(:bar)
      end)

      expect(MultiBarStateMock, :enter, fn chat -> Chat.reply_with(chat, "transfered") end)

      {:ok, bot} = Bot.start_link(MultiMock, :ok, states: @states)
      allow(MultiMock, self(), bot)
      allow(MultiFooStateMock, self(), bot)
      allow(MultiBarStateMock, self(), bot)

      assert ["transfering", "transfered"] = Bot.begin(bot)
    end

    test "Chat.goto/2 when injecting intermediate state" do
      expect(MultiMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

      MultiFooStateMock
      |> expect(:enter, fn chat -> chat end)
      |> expect(:on, fn chat, result ->
        chat |> Chat.reply_with(result) |> Chat.goto(:bar, inject: :qux)
      end)
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)

      expect(MultiQuxStateMock, :enter, fn chat -> Chat.reply_with(chat, "injected") end)

      {:ok, bot} = Bot.start_link(MultiMock, :ok, states: @states)
      allow(MultiMock, self(), bot)
      allow(MultiFooStateMock, self(), bot)
      allow(MultiQuxStateMock, self(), bot)
      Bot.begin(bot)

      assert "injected" = Bot.send(bot, "FOObAr")
    end

    test "Chat.goto/2 when injecting intermediate state and continue" do
      expect(MultiMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

      MultiFooStateMock
      |> expect(:enter, fn chat -> chat end)
      |> expect(:on, fn chat, _ ->
        chat |> Chat.reply_with("foo") |> Chat.goto(:bar, inject: :qux)
      end)
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)

      expect(MultiBarStateMock, :enter, fn chat -> Chat.reply_with(chat, "bar") end)

      expect(MultiQuxStateMock, :enter, fn chat ->
        chat |> Chat.reply_with("qux") |> Chat.continue()
      end)

      {:ok, bot} = Bot.start_link(MultiMock, :ok, states: @states)
      allow(MultiMock, self(), bot)
      allow(MultiFooStateMock, self(), bot)
      allow(MultiBarStateMock, self(), bot)
      allow(MultiQuxStateMock, self(), bot)
      Bot.begin(bot)

      assert ["foo", "qux", "bar"] = Bot.send(bot, "anything")
    end
  end

  describe "async bot" do
    test "begin_chat/1" do
      MultiMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, fn chat, message -> send(chat.data, message) end)

      expect(MultiFooStateMock, :enter, fn chat -> Chat.reply_with(chat, "hi") end)

      {:ok, bot} = Bot.start_link(MultiMock, self(), states: @states)
      allow(MultiFooStateMock, self(), bot)
      allow(MultiMock, self(), bot)
      :ok = Bot.begin_async(bot)
      assert_receive "hi"
    end

    test "state_pipeline/1, on/2" do
      MultiMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, fn chat, message -> send(chat.data, message) end)

      MultiFooStateMock
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)
      |> expect(:enter, fn chat -> chat end)
      |> expect(:on, fn chat, result -> Chat.reply_with(chat, result) end)

      {:ok, bot} = Bot.start_link(MultiMock, self(), states: @states)
      allow(MultiMock, self(), bot)
      allow(MultiFooStateMock, self(), bot)

      :ok = Bot.begin_async(bot)
      :ok = Bot.send_async(bot, "Hello")

      assert_receive "hello"
    end

    test "Chat.goto/2 on enter" do
      MultiMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, fn chat, message -> send(chat.data, message) end)

      expect(MultiFooStateMock, :enter, fn chat ->
        chat |> Chat.reply_with("transfering") |> Chat.goto(:bar)
      end)

      expect(MultiBarStateMock, :enter, fn chat -> Chat.reply_with(chat, "transfered") end)

      {:ok, bot} = Bot.start_link(MultiMock, self(), states: @states)
      allow(MultiMock, self(), bot)
      allow(MultiFooStateMock, self(), bot)
      allow(MultiBarStateMock, self(), bot)

      :ok = Bot.begin_async(bot)

      assert_receive ["transfering", "transfered"]
    end

    test "Chat.goto/2 when injecting intermediate state" do
      MultiMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, fn chat, message -> send(chat.data, message) end)

      MultiFooStateMock
      |> expect(:enter, fn chat -> chat end)
      |> expect(:on, fn chat, result ->
        chat |> Chat.reply_with(result) |> Chat.goto(:bar, inject: :qux)
      end)
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)

      expect(MultiQuxStateMock, :enter, fn chat -> Chat.reply_with(chat, "injected") end)

      {:ok, bot} = Bot.start_link(MultiMock, self(), states: @states)
      allow(MultiMock, self(), bot)
      allow(MultiFooStateMock, self(), bot)
      allow(MultiQuxStateMock, self(), bot)

      :ok = Bot.begin_async(bot)
      :ok = Bot.send_async(bot, "FOObAr")

      assert_receive "injected"
    end

    test "Chat.goto/2 when injecting intermediate state and continue" do
      MultiMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, fn chat, message -> send(chat.data, message) end)

      MultiFooStateMock
      |> expect(:enter, fn chat -> chat end)
      |> expect(:on, fn chat, _ ->
        chat |> Chat.reply_with("foo") |> Chat.goto(:bar, inject: :qux)
      end)
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)

      expect(MultiBarStateMock, :enter, fn chat -> Chat.reply_with(chat, "bar") end)

      expect(MultiQuxStateMock, :enter, fn chat ->
        chat |> Chat.reply_with("qux") |> Chat.continue()
      end)

      {:ok, bot} = Bot.start_link(MultiMock, self(), states: @states)
      allow(MultiMock, self(), bot)
      allow(MultiFooStateMock, self(), bot)
      allow(MultiBarStateMock, self(), bot)
      allow(MultiQuxStateMock, self(), bot)

      :ok = Bot.begin_async(bot)
      :ok = Bot.send_async(bot, "anything")

      assert_receive  ["foo", "qux", "bar"]
    end
  end
end
