defmodule Remit.RepoTest do
  use Remit.DataCase, async: true
  alias Remit.{Repo, Factory, Commit}

  describe "last" do
    test "gets the last queryable by ID" do
      _commit_2 = Factory.insert!(:commit, id: 2)
       commit_3 = Factory.insert!(:commit, id: 3)
      _commit_1 = Factory.insert!(:commit, id: 1)

      assert Repo.last(Commit) == commit_3
    end

    test "allows a complex queryable" do
       commit_2 = Factory.insert!(:commit, id: 2, repo: "footguns")
      _commit_3 = Factory.insert!(:commit, id: 3, repo: "facepalms")
      _commit_1 = Factory.insert!(:commit, id: 1, repo: "footguns")

      assert Repo.last(from c in Commit, where: c.repo == "footguns") == commit_2
    end

    test "lets you override the ordering" do
       commit_2 = Factory.insert!(:commit, id: 2, sha: "a")
      _commit_3 = Factory.insert!(:commit, id: 3, sha: "b")
       commit_1 = Factory.insert!(:commit, id: 1, sha: "c")

      assert Repo.last(from Commit, order_by: [asc: :sha]) == commit_2
      assert Repo.last(from Commit, order_by: [asc: :id]) == commit_1
    end
  end
end
