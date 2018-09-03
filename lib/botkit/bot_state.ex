defmodule BotKit.BotState do
  @callback enter(Chat.t()) :: Chat.t()
  @callback leave(Chat.t()) :: Chat.t()
  @callback on(Chat.t(), term) :: Chat.t()
  @callback confused(Chat.t(), number, term) :: Chat.t()
  @callback state_pipeline(String.t()) :: term
  @optional_callbacks state_pipeline: 1, enter: 1, leave: 1, confused: 3
end
