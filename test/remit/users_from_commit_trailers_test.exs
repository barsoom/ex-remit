defmodule Remit.UsersFromCommitTrailersTest do
  use Remit.DataCase
  alias Remit.{UsersFromCommitTrailers, Commit}

  test "it parses the email address from the commit trailer" do
    commit = %Commit{
      message: Faker.message_with_co_authors("My fancy commit", ["dwight <dwight.shrute@dundermifflin.com>", "michael <michael.scott@dundermifflin.com>"])
    }

    result = UsersFromCommitTrailers.call(commit)

    assert result == ["dwight.shrute@dundermifflin.com", "michael.scott@dundermifflin.com"]
  end

  test "it returns an empty list if there are no co-authors" do
    commit = %Commit{
      message: Faker.message()
    }

    result = UsersFromCommitTrailers.call(commit)
    assert result == []
  end

  test "it returns an empty list if there is no commit message" do
    commit = %Commit{
      message: nil
    }

    result = UsersFromCommitTrailers.call(commit)
    assert result == []
  end
end
