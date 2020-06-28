defmodule RemitWeb.LiveViewHelpersTest do
  use ExUnit.Case, async: true
  alias RemitWeb.LiveViewHelpers

  describe "github_avatar" do
    test "generates an img" do
      html = LiveViewHelpers.github_avatar("foo", 123) |> to_s()
      assert html =~ ~s{<img}
      assert html =~ ~s{src="https://github.com/foo.png?size=123"}
    end

    test "uses the 'dependabot' avatar for 'dependabot-preview'" do
      html = LiveViewHelpers.github_avatar("dependabot-preview", 123) |> to_s()
      assert html =~ ~s{src="https://github.com/dependabot.png?size=123"}
    end

    defp to_s(safe), do: Phoenix.HTML.safe_to_string(safe)
  end
end
