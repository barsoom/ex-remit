defmodule Remit.UsernamesFromMentions do
  import Ecto.Query
  alias Remit.{Comment, Commit, Repo}

  # Partially from: https://github.com/shinnn/github-username-regex/blob/master/index.js
  @mention_re ~r/
    (?<=^|\W)  # The ?<= is a lookbehind: We must be at start of string, or following a non-word character.
    @
    (
      [a-z\d]                         # Starts with ASCII letter or digit.
      (?:[a-z\d]|-(?=[a-z\d])){0,38}  # The ?= is a lookahead: any "-" must be followed by a letter or digit.
    )
    \b
  /ix

  def call(text) do
    @mention_re
    |> Regex.scan(strip_code_blocks(text), capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
    |> do_call()
  end

  # Private

  defp do_call([]), do: []
  defp do_call(mentions) do
    known_usernames = get_known_usernames()

    # We normalise to the known form, because it's probably from GitHub's APIs, so should have correct casing.
    # (Which we probably don't *need*, but why not?)
    Enum.flat_map(mentions, fn mention ->
      downcased_mention = String.downcase(mention)
      Enum.find_value(known_usernames, [], &(if String.downcase(&1) == downcased_mention, do: [&1]))
    end)
  end

  # This is simplistic and doesn't e.g. account for HTML-in-Markdown or backslash-escaped backticks. But probably good enough.
  defp strip_code_blocks(text) do
    text
    |> String.replace(~r/^    .*/m, "")        # Four-space indent.
    |> String.replace(~r/^```(.*?)```/ms, "")  # Triple backticks.
    |> String.replace(~r/`(.*?)`/, "")         # Single backticks.
  end

  defp get_known_usernames do
    # UNION ALL to minimise DB roundtrips.
    # UNION ALL rather than UNION because it's faster, we can't easily get unique values anyway.
    # COALESCE because empty lists would otherwise ARRAY_AGG to `[nil]`.

    commenter_usernames_q = from c in Comment, select: fragment("COALESCE(ARRAY_AGG(DISTINCT ?), '{}')", c.commenter_username)

    from(c in Commit, select: c.usernames, distinct: true, union_all: ^commenter_usernames_q)
    |> Repo.all()
    |> List.flatten()
    |> Enum.uniq()
  end
end
