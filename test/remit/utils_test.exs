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

  describe "ensure_usec" do
    test "adds it if not present" do
      no_usec = DateTime.utc_now() |> DateTime.truncate(:second)
      assert Utils.ensure_usec(no_usec) |> DateTime.to_iso8601() |> String.ends_with?(".000000Z")
    end

    test "keeps it if present" do
      with_usec = %{DateTime.utc_now() | microsecond: {123, 6}}
      assert Utils.ensure_usec(with_usec) |> DateTime.to_iso8601() |> String.ends_with?(".000123Z")
    end
  end
end
