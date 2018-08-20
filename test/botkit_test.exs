defmodule BotkitTest do
  use ExUnit.Case
  doctest BotKit

  test "greets the world" do
    assert BotKit.hello() == :world
  end
end
