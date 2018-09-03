defmodule BotKit.Examples.SmartSmokefreed.Bye do
  alias BotKit.BotState
  alias BotKit.Chat

  @behaviour BotState

  def enter(chat) do
    Chat.reply_with(chat, "It was nice talking to you. Thanks")
  end

  def on(chat, _) do
    Chat.reply_with(chat, "I'm done talking to you")
  end
end
