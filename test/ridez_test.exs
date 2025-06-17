defmodule RidezTest do
  use ExUnit.Case
  doctest Ridez

  test "greets the world" do
    assert Ridez.hello() == :world
  end
end
