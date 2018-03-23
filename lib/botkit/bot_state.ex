defmodule BotKit.BotState do
  @callback on(term, term) :: {:next, BotKit.Bot.state(), term} | {:stay, term}

  defmacro __using__(_) do
    quote do
      @behaviour BotKit.BotState
    end
  end
end
