defmodule Remit.UtilsTest do
  use ExUnit.Case, async: true
  alias Remit.Utils

  describe "usernames_from_email" do
    test "extracts them from plus addressing" do
      assert Utils.usernames_from_email("foo+one+two@example.com") ==
        ["one", "two"]
    end

    test "handles '-'" do
      assert Utils.usernames_from_email("foo+g-boll+k-stropp@example.com") ==
        ["g-boll", "k-stropp"]
    end

    test "returns an empty list if there's nothing" do
      assert Utils.usernames_from_email("foo@example.com") == []
    end
  end
end
