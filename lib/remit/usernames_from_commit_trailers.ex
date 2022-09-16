defmodule Remit.UsernamesFromCommitTrailers do
  @moduledoc false
  @trailer_email_re ~r/<(.*)>/ix
  @user_from_email_re ~r/\d*?\+?([^\+]*)@users\.noreply\.github\.com/ix

  def call(message) when is_binary(message) do
    message
    |> String.split("\n")
    |> Enum.filter(fn line -> String.starts_with?(line, "Co-authored-by") end)
    |> Enum.flat_map(fn trailer -> Regex.scan(@trailer_email_re, trailer, capture: :all_but_first) end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.flat_map(&usernames_from_email/1)
    |> Enum.reject(&is_nil/1)
  end

  def call(_message), do: []

  defp usernames_from_email(email) when is_binary(email) do
    if String.contains?(email, "users.noreply.github.com") do
      Regex.scan(@user_from_email_re, email, capture: :all_but_first)
      |> List.flatten()
    else
      # Here we would try to get the username through GitHub api
      []
    end
  end
end
