defmodule GenBot.SingleBotTest do
  alias GenBot.{Bot, Bot, SingleStateMock}

  use ExUnit.Case
  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  test "init/1 callback" do
    expect(SingleStateMock, :init, fn :foobar -> {:ok, %{foo: :bar}} end)

    assert {:ok, bot} = GenBot.start_link(SingleStateMock, :foobar)
  end

  describe "sync bot" do
    test "begin/1" do
      SingleStateMock
      |> expect(:init, fn :ok -> {:ok, %{foo: :bar}} end)
      |> expect(:enter, fn bot -> Bot.reply_with(bot, "hi") end)

      {:ok, bot} = GenBot.start_link(SingleStateMock, :ok)
      assert "hi" = GenBot.begin(bot)
    end

    test "pipeline/1, on/2" do
      SingleStateMock
      |> expect(:init, fn :ok -> {:ok, %{foo: :bar}} end)
      |> expect(:pipeline, fn result -> String.downcase(result) end)
      |> expect(:enter, fn it -> it end)
      |> expect(:on, fn bot, result -> Bot.reply_with(bot, result) end)

      {:ok, bot} = GenBot.start_link(SingleStateMock, :ok)
      GenBot.begin(bot)
      assert "foobar" = GenBot.send(bot, "FOObAr")
    end
  end

  describe "async bot" do
    test "begin/1" do
      SingleStateMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, fn bot, message -> send(bot.data, message) end)
      |> expect(:enter, fn bot -> Bot.reply_with(bot, "hi") end)

      {:ok, bot} = GenBot.start_link(SingleStateMock, self())
      assert :ok = GenBot.begin_async(bot)
      assert_receive "hi"
    end

    test "pipeline/1, on/2" do
      SingleStateMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:reply, 2, fn bot, message -> send(bot.data, message) end)
      |> expect(:pipeline, fn result -> String.downcase(result) end)
      |> expect(:enter, fn bot -> Bot.reply_with(bot, "enter") end)
      |> expect(:on, fn bot, result -> Bot.reply_with(bot, result) end)

      {:ok, bot} = GenBot.start_link(SingleStateMock, self())
      :ok = GenBot.begin_async(bot)
      :ok = GenBot.send_async(bot, "FOOBAR")
      assert_receive "enter"
      assert_receive "foobar"
    end
  end
end
