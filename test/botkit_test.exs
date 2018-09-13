defmodule BotKit.BotTest do
  alias BotKit.{
    Bot,
    Chat,
    SingleMock,
    MultiMock,
    MultiFooStateMock,
    MultiBarStateMock,
    MultiQuxStateMock
  }

  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  describe "Single state bot" do
    test "initliazes process" do
      expect(SingleMock, :init, fn :foobar -> {:ok, %{foo: :bar}} end)

      assert {:ok, bot} = Bot.start_link(SingleMock, :foobar)
    end

    test "replies when begining a chat" do
      SingleMock
      |> expect(:init, fn :ok -> {:ok, %{foo: :bar}} end)
      |> expect(:enter, fn chat -> Chat.reply_with(chat, "hi") end)

      assert {:ok, bot} = Bot.start_link(SingleMock, :ok)
      allow(SingleMock, self(), bot)
      assert "hi" = Bot.begin(bot)
    end

    test "process utterances through pipeline" do
      SingleMock
      |> expect(:init, fn :ok -> {:ok, %{foo: :bar}} end)
      |> expect(:enter, fn it -> it end)
      |> expect(:on, fn chat, result -> Chat.reply_with(chat, result) end)
      |> expect(:pipeline, fn result -> String.downcase(result) end)

      {:ok, bot} = Bot.start_link(SingleMock, :ok)
      allow(SingleMock, self(), bot)
      Bot.begin(bot)
      assert "foobar" = Bot.send(bot, "FOObAr")
    end
  end

  describe "Multi state bot" do
    test "initliazes process" do
      expect(MultiMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

      states = [foo: MultiFooStateMock, bar: MultiBarStateMock]
      assert {:ok, bot} = Bot.start_link(MultiMock, :ok, states: states)
    end

    test "replies when begining a chat" do
      expect(MultiMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)
      expect(MultiFooStateMock, :enter, fn chat -> Chat.reply_with(chat, "hi") end)

      states = [foo: MultiFooStateMock, bar: MultiBarStateMock]
      assert {:ok, bot} = Bot.start_link(MultiMock, :ok, states: states)
      allow(MultiFooStateMock, self(), bot)
      assert "hi" = Bot.begin(bot)
    end

    test "process utterances through pipeline" do
      expect(MultiMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

      MultiFooStateMock
      |> expect(:enter, fn chat -> chat end)
      |> expect(:on, fn chat, result -> Chat.reply_with(chat, result) end)
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)

      states = [foo: MultiFooStateMock, bar: MultiBarStateMock]
      {:ok, bot} = Bot.start_link(MultiMock, :ok, states: states)
      allow(MultiMock, self(), bot)
      allow(MultiFooStateMock, self(), bot)
      Bot.begin(bot)
      assert "foobar" = Bot.send(bot, "FOObAr")
    end

    test "triggers state transition when requested from enter callback" do
      expect(MultiMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

      expect(MultiFooStateMock, :enter, fn chat ->
        chat |> Chat.reply_with("transfering") |> Chat.goto(:bar)
      end)

      expect(MultiBarStateMock, :enter, fn chat -> Chat.reply_with(chat, "transfered") end)

      states = [foo: MultiFooStateMock, bar: MultiBarStateMock]
      {:ok, bot} = Bot.start_link(MultiMock, :ok, states: states)
      allow(MultiMock, self(), bot)
      allow(MultiFooStateMock, self(), bot)
      allow(MultiBarStateMock, self(), bot)

      assert ["transfering", "transfered"] = Bot.begin(bot)
    end

    test "injects intermediate fsm states without leaving" do
      expect(MultiMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

      MultiFooStateMock
      |> expect(:enter, fn chat -> chat end)
      |> expect(:on, fn chat, result ->
        chat |> Chat.reply_with(result) |> Chat.goto(:bar, inject: :qux)
      end)
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)

      expect(MultiQuxStateMock, :enter, fn chat -> Chat.reply_with(chat, "injected") end)

      states = [foo: MultiFooStateMock, bar: MultiBarStateMock, qux: MultiQuxStateMock]
      {:ok, bot} = Bot.start_link(MultiMock, :ok, states: states)
      allow(MultiMock, self(), bot)
      allow(MultiFooStateMock, self(), bot)
      allow(MultiQuxStateMock, self(), bot)
      Bot.begin(bot)

      assert "injected" = Bot.send(bot, "FOObAr")
    end

    test "injects intermediate fsm states and leaves it" do
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

      states = [foo: MultiFooStateMock, bar: MultiBarStateMock, qux: MultiQuxStateMock]
      {:ok, bot} = Bot.start_link(MultiMock, :ok, states: states)
      allow(MultiMock, self(), bot)
      allow(MultiFooStateMock, self(), bot)
      allow(MultiBarStateMock, self(), bot)
      allow(MultiQuxStateMock, self(), bot)
      Bot.begin(bot)

      assert ["foo", "qux", "bar"] = Bot.send(bot, "anything")
    end
  end
end
