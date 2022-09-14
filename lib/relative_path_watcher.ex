defmodule RelativePathWatcher do
  @moduledoc false

  @doc """
  Starts the watcher with an absolute path to the command.

  `System.cmd/3` will try to resolve e.g. "node" from `PATH` before cd-ing into the working directory,
  which in the devbox setup will return a relative path which will no longer be valid after cd-ing.
  For this to work, we need to absolutize it early on.
  """
  def watch(cmd, args) when is_binary(cmd) do
    cmd = resolve_command(cmd)
    Phoenix.Endpoint.Watcher.watch(cmd, args)
  end

  defp resolve_command(cmd) do
    if Path.type(cmd) == :absolute, do: cmd, else: try_path_lookup(cmd)
  end

  defp try_path_lookup(cmd) do
    case :os.find_executable(String.to_charlist(cmd)) do
      path when is_list(path) ->
        path |> List.to_string() |> Path.absname()
      false ->
        raise "could not resolve '#{cmd}' to an executable"
    end
  end
end
