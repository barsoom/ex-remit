defmodule Gravatar do
  def url(email, size \\ 80) do
    # https://en.gravatar.com/site/implement/images/
    "https://www.gravatar.com/avatar/#{hash(email)}?s=#{size}&d=monsterid"
  end

  defp hash(nil), do: hash("")
  defp hash(email) do
    :crypto.hash(:md5, email)
    |> Base.encode16(case: :lower)
  end
end
