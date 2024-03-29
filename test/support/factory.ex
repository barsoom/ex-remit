defmodule Remit.Factory do
  @moduledoc """
  Test factories, based on the pattern in https://hexdocs.pm/ecto/test-factories.html.
  """

  alias Remit.{Repo, Commit, Comment, CommentNotification, Team}

  def build(:commit) do
    %Commit{
      sha: Faker.sha(),
      usernames: [Faker.username()],
      owner: "acme",
      repo: Faker.repo(),
      message: Faker.message(),
      url: "https://example.com/",
      committed_at: DateTime.utc_now(),
      unlisted: false
    }
  end

  def build(:comment) do
    %Comment{
      github_id: Faker.number(),
      body: Faker.message(),
      commenter_username: Faker.username(),
      commented_at: DateTime.utc_now(),
      commit: build(:commit)
    }
  end

  def build(:comment_notification) do
    %CommentNotification{
      username: Faker.username(),
      comment: build(:comment)
    }
  end

  def build(:team) do
    team = Faker.team()

    %Team{
      slug: String.downcase(team),
      name: team,
      projects: []
    }
  end

  def build(name, attributes) do
    name |> build() |> struct!(attributes)
  end

  def insert!(name, attributes \\ []) do
    name |> build(attributes) |> Repo.insert!()
  end
end
