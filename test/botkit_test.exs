defmodule BotkitTest do
  use ExUnit.Case
  doctest Botkit

  test "greets the world" do
    assert Botkit.hello() == :world
  end
end
