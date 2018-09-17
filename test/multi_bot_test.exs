defmodule GenBot.MultiBotTest do
  alias GenBot.{Bot, MultiStateMock, FooStateMock, BarStateMock, QuxStateMock}

  use ExUnit.Case
  import Mox

  @states [foo: FooStateMock, bar: BarStateMock, qux: QuxStateMock]

  setup :verify_on_exit!
  setup :set_mox_global

  test "init/1 callback" do
    expect(MultiStateMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

    assert {:ok, bot} = GenBot.start_link(MultiStateMock, :ok, states: @states)
  end

  describe "sync bot" do
    test "begin/1" do
      expect(MultiStateMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)
      expect(FooStateMock, :enter, fn bot -> Bot.reply_with(bot, "hi") end)

      {:ok, bot} = GenBot.start_link(MultiStateMock, :ok, states: @states)
      assert "hi" = GenBot.begin(bot)
    end

    test "state_pipeline/1, on/2" do
      expect(MultiStateMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

      FooStateMock
      |> expect(:enter, fn bot -> bot end)
      |> expect(:on, fn bot, result -> Bot.reply_with(bot, result) end)
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)

      {:ok, bot} = GenBot.start_link(MultiStateMock, :ok, states: @states)
      GenBot.begin(bot)
      assert "foobar" = GenBot.send(bot, "FOObAr")
    end

    test "Bot.goto/2 on enter" do
      expect(MultiStateMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

      expect(FooStateMock, :enter, fn bot ->
        bot |> Bot.reply_with("transfering") |> Bot.goto(:bar)
      end)

      expect(BarStateMock, :enter, fn bot -> Bot.reply_with(bot, "transfered") end)

      {:ok, bot} = GenBot.start_link(MultiStateMock, :ok, states: @states)

      assert ["transfering", "transfered"] = GenBot.begin(bot)
    end

    test "Bot.goto/2 when injecting intermediate state" do
      expect(MultiStateMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

      FooStateMock
      |> expect(:enter, fn bot -> bot end)
      |> expect(:on, fn bot, result ->
        bot |> Bot.reply_with(result) |> Bot.goto(:bar, inject: :qux)
      end)
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)

      expect(QuxStateMock, :enter, fn bot -> Bot.reply_with(bot, "injected") end)

      {:ok, bot} = GenBot.start_link(MultiStateMock, :ok, states: @states)
      GenBot.begin(bot)

      assert "injected" = GenBot.send(bot, "FOObAr")
    end

    test "Bot.goto/2 when injecting intermediate state and continue" do
      expect(MultiStateMock, :init, fn :ok -> {:ok, %{foo: :bar}} end)

      FooStateMock
      |> expect(:enter, fn bot -> bot end)
      |> expect(:on, fn bot, _ ->
        bot |> Bot.reply_with("foo") |> Bot.goto(:bar, inject: :qux)
      end)
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)

      expect(BarStateMock, :enter, fn bot -> Bot.reply_with(bot, "bar") end)

      expect(QuxStateMock, :enter, fn bot ->
        bot |> Bot.reply_with("qux") |> Bot.continue()
      end)

      {:ok, bot} = GenBot.start_link(MultiStateMock, :ok, states: @states)
      GenBot.begin(bot)

      assert ["qux", "foo", "bar"] = GenBot.send(bot, "anything")
    end
  end

  describe "async bot" do
    test "begin/1" do
      MultiStateMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, fn bot, message -> send(bot.data, message) end)

      expect(FooStateMock, :enter, fn bot -> Bot.reply_with(bot, "hi") end)

      {:ok, bot} = GenBot.start_link(MultiStateMock, self(), states: @states)
      :ok = GenBot.begin_async(bot)
      assert_receive "hi"
    end

    test "state_pipeline/1, on/2" do
      MultiStateMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, 2, fn bot, message -> send(bot.data, message) end)

      FooStateMock
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)
      |> expect(:enter, fn bot -> bot end)
      |> expect(:on, fn bot, result -> Bot.reply_with(bot, result) end)

      {:ok, bot} = GenBot.start_link(MultiStateMock, self(), states: @states)

      :ok = GenBot.begin_async(bot)
      :ok = GenBot.send_async(bot, "Hello")

      assert_receive "hello"
    end

    test "Bot.goto/2 on enter" do
      MultiStateMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, fn bot, message -> send(bot.data, message) end)

      expect(FooStateMock, :enter, fn bot ->
        bot |> Bot.reply_with("transfering") |> Bot.goto(:bar)
      end)

      expect(BarStateMock, :enter, fn bot -> Bot.reply_with(bot, "transfered") end)

      {:ok, bot} = GenBot.start_link(MultiStateMock, self(), states: @states)

      :ok = GenBot.begin_async(bot)

      assert_receive ["transfering", "transfered"]
    end

    test "Bot.goto/2 when injecting intermediate state" do
      MultiStateMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, 2, fn bot, message -> send(bot.data, message) end)

      FooStateMock
      |> expect(:enter, fn bot -> bot end)
      |> expect(:on, fn bot, result ->
        bot |> Bot.reply_with(result) |> Bot.goto(:bar, inject: :qux)
      end)
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)

      expect(QuxStateMock, :enter, fn bot -> Bot.reply_with(bot, "injected") end)

      {:ok, bot} = GenBot.start_link(MultiStateMock, self(), states: @states)

      :ok = GenBot.begin_async(bot)
      :ok = GenBot.send_async(bot, "FOObAr")

      assert_receive "injected"
    end

    test "Bot.goto/2 when injecting intermediate state and continue" do
      MultiStateMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, 2, fn bot, message -> send(bot.data, message) end)

      FooStateMock
      |> expect(:enter, fn bot -> bot end)
      |> expect(:on, fn bot, _ ->
        bot |> Bot.reply_with("foo") |> Bot.goto(:bar, inject: :qux)
      end)
      |> expect(:state_pipeline, fn result -> String.downcase(result) end)

      expect(BarStateMock, :enter, fn bot -> Bot.reply_with(bot, "bar") end)

      expect(QuxStateMock, :enter, fn bot ->
        bot |> Bot.reply_with("qux") |> Bot.continue()
      end)

      {:ok, bot} = GenBot.start_link(MultiStateMock, self(), states: @states)

      :ok = GenBot.begin_async(bot)
      :ok = GenBot.send_async(bot, "anything")

      assert_receive ["qux", "foo", "bar"]
    end
  end
end
