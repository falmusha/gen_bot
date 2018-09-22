defmodule GenBot.Test.BotCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Mox

      setup :verify_on_exit!
      setup :set_mox_global
    end
  end
end
