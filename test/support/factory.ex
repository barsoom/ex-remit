# https://hexdocs.pm/ecto/test-factories.html

defmodule Remit.Factory do
  alias Remit.{Repo, Commit}

  def build(:commit) do
    %Commit{
      sha: Faker.sha(),
      author_email: Faker.email(),
      author_name: Faker.human_name(),
      author_usernames: [Faker.username()],
      owner: "acme",
      repo: Faker.repo(),
      message: Faker.message(),
      url: "https://example.com/",
      committed_at: (DateTime.utc_now() |> DateTime.truncate(:second)),
    }
  end

  def build(name, attributes) do
    name |> build() |> struct(attributes)
  end

  def insert!(factory_name, attributes \\ []) do
    build(factory_name, attributes) |> Repo.insert!
  end
end
