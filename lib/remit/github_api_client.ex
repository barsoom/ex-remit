defmodule Remit.GitHubAPIClient do
  defmodule Behaviour do
    @moduledoc false
    @callback fetch_commit(String.t(), String.t(), String.t()) :: %Remit.Commit{}
    @callback fetch_comments_on_commit(%Remit.Commit{}) :: [%Remit.Comment{}]
  end

  @behaviour Behaviour

  alias Remit.{Commit, Comment, Utils}

  def fetch_commit(owner, repo, sha) do
    {:ok, %{body: data}} = Tesla.get(tesla_client(), "/repos/#{owner}/#{repo}/commits/#{sha}")

    build_commit(data, owner, repo, sha)
  end

  def fetch_comments_on_commit(%Commit{owner: owner, repo: repo, sha: sha}) do
    {:ok, %{body: data}} = Tesla.get(tesla_client(), "/repos/#{owner}/#{repo}/commits/#{sha}/comments")

    data |> Enum.map(&build_comment/1)
  end

  def get_user(bearer_token) do
    {:ok, %{body: data}} = Tesla.get(tesla_client(bearer_token), "/user")
    build_user(data)
  end

  def get_teams(bearer_token, org_slug) do
    {:ok, %{body: data}} = Tesla.get(tesla_client(bearer_token), "/orgs/#{org_slug}/teams")
    data
  end

  # Sometimes it's easiest to just follow a provided URL to read related resources, like team members.
  def get_resource(bearer_token, url) do
    {:ok, %{body: data}} = Tesla.get(tesla_client(bearer_token), url)
    data
  end

  defp build_commit(
         %{
           "sha" => sha,
           "html_url" => url,
           "commit" => %{
             "message" => message,
             "author" => %{
               "email" => author_email
             },
             "committer" => %{
               "email" => committer_email,
               "date" => raw_committed_at
             }
           },
           "author" => author_account,
           "committer" => committer_account
         } = payload,
         owner,
         repo,
         sha
       ) do
    %Commit{
      owner: owner,
      repo: repo,
      sha: sha,
      url: url,
      usernames: usernames([author_email, committer_email], [author_account, committer_account]),
      message: message,
      committed_at: Utils.date_time_from_iso8601!(raw_committed_at),
      payload: payload
    }
  end

  defp build_comment(
         %{
           "id" => github_id,
           "commit_id" => sha,
           "body" => body,
           "created_at" => raw_commented_at,
           "user" => %{"login" => username},
           "path" => path,
           "position" => position
         } = payload
       ) do
    %Comment{
      github_id: github_id,
      commit_sha: sha,
      body: body,
      commented_at: Utils.date_time_from_iso8601!(raw_commented_at),
      commenter_username: username,
      path: path,
      position: position,
      payload: payload
    }
  end

  defp usernames(emails, accounts) do
    (usernames_from_emails(emails) ++ usernames_from_accounts(accounts))
    |> Enum.uniq_by(&String.downcase/1)
  end

  defp usernames_from_accounts(accounts) do
    accounts
    |> Enum.flat_map(fn
      %{"login" => login} -> [login]
      _ -> []
    end)
  end

  defp usernames_from_emails(emails) do
    emails |> Enum.flat_map(&Utils.usernames_from_email/1)
  end

  defp build_user(data) do
    %Remit.Github.User{
      login: data["login"],
    }
  end

  defp tesla_client(bearer_token \\ nil) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "https://api.github.com"},
      {Tesla.Middleware.Headers, [{"authorization", authorization(bearer_token)}]},
      Tesla.Middleware.JSON
    ])
  end

  defp authorization(nil), do: "token " <> Remit.Config.github_api_token()
  defp authorization(token), do: "bearer " <> token
end
