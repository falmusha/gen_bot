defmodule BotKit.Examples.SmartSmokefreed.AskIfSmoker do
  alias BotKit.BotState
  alias BotKit.Chat

  @behaviour BotState

  def enter(chat) do
    chat
    |> Chat.reply_with("Hi my name is smokefreed.")
    |> Chat.reply_with("Do you smoke?")
  end

  def on(chat, text) when text in ["yes", "no"] do
    case text do
      "yes" -> Chat.reply_with(chat, "I see, you do smoke")
      "no" -> Chat.reply_with(chat, "Good for you, you don't smoke")
    end
    |> Chat.goto(:bye)
  end

  def confused(chat, tries, _text) when tries > 3 do
    chat
    |> Chat.reply_with("Do you smoke? Answer with yes or no")
    |> Chat.reset_confused_count()
  end

  def confused(chat, _, text) do
    chat
    |> Chat.reply_with("Sorry, I don't undestand what mean by '#{text}'")
    |> Chat.reply_with("Do you smoke?")
  end
end
