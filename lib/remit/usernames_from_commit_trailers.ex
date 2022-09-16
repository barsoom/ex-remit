defmodule Remit.UsernamesFromCommitTrailers do
  @moduledoc false
  @co_author_line_re ~r/^Co-authored-by: .*<(.+)>/im
  @github_email_re ~r/([^+]+)@users\.noreply\.github\.com\z/i

  def call(message) when is_binary(message) do
    message
    |> find_co_author_emails
    |> Enum.flat_map(&usernames_from_email/1)
    |> Enum.uniq()
  end

  def call(_message), do: []

  defp find_co_author_emails(message) do
    Regex.scan(@co_author_line_re, message, capture: :all_but_first)
    |> List.flatten()
  end

  defp usernames_from_email(email) do
    case Regex.run(@github_email_re, email, capture: :all_but_first) do
      [username] -> [username]
      nil ->
         # TODO figure out a way to get the github username from an email
        []
    end
  end
end
