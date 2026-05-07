defmodule Remit.CLITest do
  use ExUnit.Case, async: true
  alias Remit.CLI

  test "parses commits list with flags" do
    assert {["commits", "list"], %{json: true, limit: 10}} =
             CLI.parse(["--json", "commits", "list", "--limit", "10"])
  end

  test "parses commits review with id positional" do
    assert {["commits", "review", "42"], %{}} = CLI.parse(["commits", "review", "42"])
  end

  test "parses comments list with --is and --role" do
    assert {["comments", "list"], %{is: "resolved", role: "all"}} =
             CLI.parse(["comments", "list", "--is", "resolved", "--role", "all"])
  end
end
