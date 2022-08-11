defmodule Remit.ListExt do

  @moduledoc ~S"""
  Utility extensions for the core `List`.
  """

  @doc ~S"""
  Like `List.delete/2`, but also returns whether the element was a member of the list.

  Works in a single pass, so more efficient than `Enum.member?` + `List.delete`.

  ## Examples

    iex> Remit.ListExt.delete_check([], 1)
    {false, []}

    iex> Remit.ListExt.delete_check([1], 1)
    {true, []}

    iex> Remit.ListExt.delete_check([1], 2)
    {false, [1]}

    iex> Remit.ListExt.delete_check([1, 2, 3], 2)
    {true, [1, 3]}

    iex> Remit.ListExt.delete_check([1, 2, 3], 4)
    {false, [1, 2, 3]}
  """
  @spec delete_check([], any) :: {false, []}
  @spec delete_check([...], any) :: {boolean(), list()}
  def delete_check(list, element)
  def delete_check([], _), do: {false, []}
  def delete_check([element | tail], element), do: {true, tail}
  def delete_check([x | tail], element) do
    {member, tail} = delete_check(tail, element)
    {member, [x | tail]}
  end
end
