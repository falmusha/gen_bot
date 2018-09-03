defmodule BotKit.Examples.Smokefreed do
  alias BotKit.Bot
  alias BotKit.Chat

  @behaviour BotKit.Bot
  @behaviour BotKit.BotState

  def start_link() do
    Bot.start_link(__MODULE__, nil)
  end

  def init(nil) do
    {:ok, %{}}
  end

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

  def pipeline(text) do
    String.downcase(text)
  end
end
