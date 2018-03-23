defmodule BotKit.Test do
  use BotKit.Bot

  alias BotKit.Bot

  def start_link() do
    Bot.start_link(__MODULE__, %{})
  end

  def say(pid) do
    Bot.say(pid, "hi")
  end

  def on(result, _state, data) do
    IO.inspect(result)
    {:next, :some_other_state, data}
  end

  def pipeline(_pipeline, text) do
    text
  end
end
