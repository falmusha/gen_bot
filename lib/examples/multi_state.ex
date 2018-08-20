defmodule BotKit.Examples.MultieState do
  alias BotKit.Bot

  use Bot, states: [state_a: BotKit.Examples.StateA, state_b: BotKit.Examples.StateB]

  def start_link() do
    Bot.start_link(__MODULE__, %{})
  end

  @impl true
  def init(_args) do
    {:ok, %{}}
  end

  @impl true
  def pipeline(text) do
    text
  end
end
