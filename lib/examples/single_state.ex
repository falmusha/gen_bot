defmodule BotKit.Examples.SingleState do
  alias BotKit.Bot
  alias BotKit.Chat

  use Bot

  def start_link() do
    Bot.start_link(__MODULE__, %{})
  end

  @impl true
  def init(args) do
    {:ok, args}
  end

  @impl true
  def enter(chat) do
    Chat.put_reply(chat, "Hello There")
  end

  @impl true
  def on(chat, text) do
    Chat.put_reply(chat, text)
  end

  @impl true
  def pipeline(text) do
    String.upcase(text)
  end
end
