defmodule Remit.UsernamesFromCommitTrailersTest do
  use Remit.DataCase
  alias Remit.UsernamesFromCommitTrailers

  test "it parses the email address from the commit trailer" do
    result =
      Faker.message_with_co_authors("My fancy commit", ["dwight <dwight.shrute@users.noreply.github.com>", "michael <123+michael.scott@users.noreply.github.com>"])
      |> UsernamesFromCommitTrailers.call()

    assert result == ["dwight.shrute", "michael.scott"]
  end

  test "it returns an empty list if there are no co-authors" do
    result = UsernamesFromCommitTrailers.call(Faker.message())
    assert result == []
  end

  test "it returns an empty list if there is no commit message" do
    result = UsernamesFromCommitTrailers.call(nil)
    assert result == []
  end
end
