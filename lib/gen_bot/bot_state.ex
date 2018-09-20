defmodule GenBot.BotState do
  @callback enter(Bot.t()) :: Bot.t()

  @callback leave(Bot.t()) :: Bot.t()

  @callback on(Bot.t(), term) :: Bot.t()

  @callback confused(Bot.t(), number, term) :: Bot.t()

  @callback state_pipeline(Bot.t(), String.t()) :: term

  @optional_callbacks state_pipeline: 2, enter: 1, on: 2, leave: 1, confused: 3
end
