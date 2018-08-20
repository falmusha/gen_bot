defmodule BotKit.Examples.StateB do
  alias BotKit.BotState
  alias BotKit.Chat

  use BotState

  @impl true
  def enter(chat) do
    Chat.put_reply(chat, "Entered state B")
  end

  @impl true
  def leave(chat) do
    chat
  end

  @impl true
  def on(chat, text) do
    Chat.put_reply(chat, "from B #{text}")
  end
end
