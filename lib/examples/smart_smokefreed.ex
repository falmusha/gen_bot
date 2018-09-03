defmodule BotKit.Examples.SmartSmokefreed do
  alias BotKit.Bot

  @behaviour Bot

  def start_link() do
    Bot.start_link(__MODULE__, %{},
      states: [
        smoker?: BotKit.Examples.SmartSmokefreed.AskIfSmoker,
        bye: BotKit.Examples.SmartSmokefreed.Bye
      ]
    )
  end

  def init(_args) do
    {:ok, %{}}
  end

  def pipeline(text) do
    String.downcase(text)
  end
end
