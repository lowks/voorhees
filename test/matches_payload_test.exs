defmodule Voorhees.Test.MatchesPayload do
  use ExUnit.Case
  import Voorhees

  test "desired keys can be either strings or atoms" do
    content = Poison.encode! %{ a: 1, b: 2 }
    assert matches_payload?(content, %{ :a => 1, "b" => 2 })
  end

  test "missing key from expected_payload returns false" do
    content = Poison.encode! %{ a: 1, b: 2 }
    assert !matches_payload?(content, %{ :a => 1, "b" => 2, :c => 3 })
  end

  test "ignores extra keys in the content passed in" do
    content = Poison.encode! %{ a: 1, b: 2, c: 3 }
    assert matches_payload?(content, %{ :a => 1, "b" => 2 })
  end

  test "validates scalar lists" do
    content = Poison.encode! %{ a: 1, b: [2] }
    assert matches_payload?(content, %{ :a => 1, "b" => [2] })

    content = Poison.encode! %{ a: 1, b: [2, 1] }
    assert !matches_payload?(content, %{ :a => 1, "b" => [2] })

    content = Poison.encode! %{ a: 1, b: [2] }
    assert !matches_payload?(content, %{ :a => 1, "b" => [1, 2] })
  end

  test "validates scalar lists with respect to array order" do
    content = Poison.encode! %{ a: 1, b: [2, 1] }
    assert !matches_payload?(content, %{ :a => 1, "b" => [1, 2] })
  end
end
