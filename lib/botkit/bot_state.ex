defmodule BotKit.BotState do
  @callback enter(Chat.t()) :: Chat.t()
  @callback leave(Chat.t()) :: Chat.t()
  @callback on(Chat.t(), term) :: Chat.t()
  @callback state_pipeline(String.t()) :: term
  @optional_callbacks state_pipeline: 1

  defmacro __using__(opts \\ [single: false]) do
    quote bind_quoted: [opts: opts] do
      @behaviour BotKit.BotState

      def enter(chat), do: chat

      if Keyword.get(opts, :single) do
        def state_pipeline(_), do: raise("You can't use state_pipeine in single state mode")
        def leave(_), do: raise("Use terminate/1")
      else
        def leave(chat), do: chat
        defoverridable leave: 1
      end

      defoverridable enter: 1
    end
  end
end
