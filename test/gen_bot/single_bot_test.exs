defmodule GenBot.SingleBotTest do
  alias GenBot.{Bot, Test.SingleStateMock}

  use ExUnit.Case
  use GenBot.Test.BotCase

  test "init/1 callback" do
    expect(SingleStateMock, :init, fn :aok -> {:ok, %{}} end)
    assert {:ok, bot} = GenBot.start_link(SingleStateMock, :aok)
  end

  describe "sync bot" do
    test "begin/1" do
      SingleStateMock
      |> expect(:init, fn :ok -> {:ok, %{foo: :bar}} end)
      |> expect(:post_hook, fn bot -> bot end)
      |> expect(:enter, fn bot -> Bot.reply_with(bot, "hi") end)

      {:ok, bot} = GenBot.start_link(SingleStateMock, :ok)

      assert "hi" = GenBot.begin(bot)
    end

    test "pipeline/2, on/2" do
      SingleStateMock
      |> expect(:init, fn :ok -> {:ok, %{foo: :bar}} end)
      |> expect(:pre_hook, fn bot, _input -> bot end)
      |> expect(:post_hook, 2, fn bot -> bot end)
      |> expect(:pipeline, fn _, result -> String.downcase(result) end)
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
      |> expect(:post_hook, fn bot -> bot end)
      |> expect(:enter, fn bot -> Bot.reply_with(bot, "hi") end)

      {:ok, bot} = GenBot.start_link(SingleStateMock, self())
      assert :ok = GenBot.begin_async(bot)
      assert_receive "hi"
    end

    test "pipeline/2, on/2" do
      SingleStateMock
      |> expect(:init, fn test_pid -> {:ok, test_pid} end)
      |> expect(:pre_hook, fn bot, _input -> bot end)
      |> expect(:post_hook, 2, fn bot -> bot end)
      |> expect(:reply, 2, fn bot, message -> send(bot.data, message) end)
      |> expect(:pipeline, fn _, result -> String.downcase(result) end)
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
