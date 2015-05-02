defmodule Voorhees.Test.MatchesSchema do
  use ExUnit.Case
  import Voorhees

  test "desired keys can be either strings or atoms" do
    content = Poison.encode! %{ a: 1, b: 2 }
    assert matches_payload?(content, %{ :a => 1, "b" => 2 })
  end
end
