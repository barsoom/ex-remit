defmodule Remit.UsernamesFromMentionsTest do
  use Remit.DataCase
  alias Remit.{UsernamesFromMentions, Factory}

  test "returns known (from commits or comments) usernames @mentioned in the text, normalised to their known form" do
    Factory.insert!(:commit, usernames: ["helLo"])
    Factory.insert!(:comment, commenter_username: "world")

    assert UsernamesFromMentions.call("Well @hello @there @WORLD") == [
             "helLo",
             "world"
           ]
  end

  test "only identifies mentions at the right boundaries" do
    Factory.insert!(:comment, commenter_username: "hello")

    assert UsernamesFromMentions.call("@hello there") == ["hello"]
    assert UsernamesFromMentions.call("well @hello") == ["hello"]
    assert UsernamesFromMentions.call(")@hello") == ["hello"]
    assert UsernamesFromMentions.call(".@hello") == ["hello"]
    assert UsernamesFromMentions.call("a@hello 1@hello _@hello @hello_") == []
  end

  test "works with all supported characters" do
    Factory.insert!(:comment, commenter_username: "h3ll-o")

    assert UsernamesFromMentions.call("(@h3ll-o)") == ["h3ll-o"]
  end

  test "ignores mentions in code blocks" do
    Factory.insert!(:comment, commenter_username: "hello")

    assert UsernamesFromMentions.call("`@hello`\n    @hello\n```\n@hello\n```") == []
  end

  test "only returns names once" do
    Factory.insert!(:comment, commenter_username: "hello")

    assert UsernamesFromMentions.call("@hello @hello") == ["hello"]
  end

  test "returns [] if nothing found" do
    assert UsernamesFromMentions.call("@hello") == []
  end
end
