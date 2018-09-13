defmodule GenBot.BotState do
  @callback enter(Bot.t()) :: Bot.t()
  @callback leave(Bot.t()) :: Bot.t()
  @callback on(Bot.t(), term) :: Bot.t()
  @callback confused(Bot.t(), number, term) :: Bot.t()
  @callback state_pipeline(String.t()) :: term
  @optional_callbacks state_pipeline: 1, enter: 1, leave: 1, confused: 3
end
