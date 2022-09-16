defmodule Remit.UsernamesFromCommitTrailersTest do
  use Remit.DataCase
  alias Remit.UsernamesFromCommitTrailers

  test "it parses the email address from the commit trailer" do
    result =
      """
      My fancy commit

      Co-authored-by: dwight <dwight.shrute@users.noreply.github.com>
      Co-authored-by: michael <123+michael.scott@users.noreply.github.com>
      """
      |> UsernamesFromCommitTrailers.call()

    assert result == ["dwight.shrute", "michael.scott"]
  end

  test "it only includes co-authors using github noreply emails" do
    result =
      """
      My fancy commit

      Co-authored-by: dwight <dwight.shrute@users.noreply.github.com>
      Co-authored-by: ryan howard <ryan.howard@wuphf.com>
      """
      |> UsernamesFromCommitTrailers.call()

    assert result == ["dwight.shrute"]
  end

  test "it returns an empty list if there are no co-authors" do
    result =
      """
      My fancy commit

      My description.
      """
      |> UsernamesFromCommitTrailers.call()

    assert result == []
  end

  test "it returns an empty list if there is no commit message" do
    result = UsernamesFromCommitTrailers.call(nil)

    assert result == []
  end
end
