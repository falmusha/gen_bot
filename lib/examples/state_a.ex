defmodule BotKit.Examples.StateA do
  alias BotKit.BotState
  alias BotKit.Chat

  use BotState

  @impl true
  def enter(chat) do
    Chat.put_reply(chat, "Entered state A")
  end

  @impl true
  def leave(chat) do
    chat
  end

  @impl true
  def on(chat, "xx") do
    chat
    |> Chat.put_reply("Gotta go to state B")
    |> Chat.goto(:state_b)
  end

  @impl true
  def on(chat, text) do
    Chat.put_reply(chat, "#{text}")
  end

  @impl true
  def state_pipeline(text) do
    String.reverse(text)
  end
end
