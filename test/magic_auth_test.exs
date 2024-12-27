defmodule MagicAuthTest do
  use ExUnit.Case
  doctest MagicAuth

  test "greets the world" do
    assert MagicAuth.hello() == :world
  end
end
