defmodule BotKit.TestBotState do
  use BotKit.BotState

  def on(_, data) do
    {:stay, data}
  end
end
