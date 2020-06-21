defmodule Remit.GitHubAPIClient do
  defmodule Behaviour do
    @moduledoc false
    @callback fetch_commit(String.t(), String.t(), String.t()) :: %Remit.Commit{}
  end
  @behaviour Behaviour

  alias Remit.Utils

  @api_token Application.get_env(:remit, :github_api_token)

  def fetch_commit(owner, repo, sha) do
    {:ok, %{body: data}} = Tesla.get(tesla_client(), "/repos/#{owner}/#{repo}/commits/#{sha}")

    build_commit(data, owner, repo, sha)
  end

  defp build_commit(%{
    "sha" => sha,
    "html_url" => url,
    "commit" => %{
      "message" => message,
      "author" => %{
        "email" => author_email,
      },
      "committer" => %{
        "email" => committer_email,
        "date" => raw_committed_at,
      },
    },
    "author" => author_account,
    "committer" => committer_account,
  } = payload, owner, repo, sha) do
    %Remit.Commit{
      owner: owner,
      repo: repo,
      sha: sha,
      url: url,
      usernames: usernames([author_email, committer_email], [author_account, committer_account]),
      message: message,
      committed_at: Utils.date_time_from_iso8601!(raw_committed_at),
      payload: payload,
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

  defp tesla_client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "https://api.github.com"},
      {Tesla.Middleware.Headers, [{"authorization", "token " <> @api_token}]},
      Tesla.Middleware.JSON,
    ])
  end
end
