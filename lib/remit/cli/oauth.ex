defmodule Remit.CLI.OAuth do
  @moduledoc """
  PKCE-based browser flow login. Generates a code_verifier + state, binds a
  localhost listener on a free ephemeral port, opens the user's browser to
  `/oauth/authorize`, catches the redirect, and exchanges the code for
  tokens.
  """
  require Logger

  @client_id "remit-cli"
  @scope "remit:read remit:review"

  def login!(base_url) do
    {verifier, challenge} = pkce_pair()
    state = random_b64(32)

    {:ok, listen_socket} = :gen_tcp.listen(0, [:binary, packet: :http_bin, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen_socket)
    redirect_uri = "http://127.0.0.1:#{port}/callback"

    authorize_url =
      base_url <>
        "/oauth/authorize?" <>
        URI.encode_query(%{
          "response_type" => "code",
          "client_id" => @client_id,
          "redirect_uri" => redirect_uri,
          "code_challenge" => challenge,
          "code_challenge_method" => "S256",
          "state" => state,
          "scope" => @scope
        })

    IO.puts("Opening browser to authenticate. If it doesn't open, visit:\n")
    IO.puts(authorize_url)
    IO.puts("")
    IO.puts("If your browser is on a different machine (so the loopback callback can't reach")
    IO.puts("this CLI), paste the full redirect URL — the one starting with")
    IO.puts("`http://127.0.0.1:#{port}/callback?code=...&state=...` — at the prompt below.")
    IO.puts("Otherwise just wait; the CLI will pick up the redirect automatically.\n")
    open_in_browser(authorize_url)

    code =
      case race_for_code(listen_socket, state) do
        {:ok, code} -> code
        {:error, reason} -> raise "login failed: #{inspect(reason)}"
      end

    :gen_tcp.close(listen_socket)

    exchange_code!(base_url, code, verifier, redirect_uri)
  end

  def exchange_code!(base_url, code, verifier, redirect_uri) do
    body =
      URI.encode_query(%{
        "grant_type" => "authorization_code",
        "code" => code,
        "code_verifier" => verifier,
        "redirect_uri" => redirect_uri,
        "client_id" => @client_id
      })

    :inets.start()
    :ssl.start()

    case :httpc.request(
           :post,
           {String.to_charlist(base_url <> "/oauth/token"), [{~c"content-type", ~c"application/x-www-form-urlencoded"}],
            ~c"application/x-www-form-urlencoded", body},
           [],
           body_format: :binary
         ) do
      {:ok, {{_, 200, _}, _, raw}} ->
        decoded = Jason.decode!(raw)

        %{
          "access_token" => decoded["access_token"],
          "refresh_token" => decoded["refresh_token"],
          "expires_at" => System.system_time(:second) + (decoded["expires_in"] || 3600),
          "base_url" => base_url
        }

      {:ok, {{_, status, _}, _, raw}} ->
        raise "token exchange failed (#{status}): #{raw}"

      {:error, reason} ->
        raise "token exchange failed: #{inspect(reason)}"
    end
  end

  # Private

  defp pkce_pair do
    verifier = :crypto.strong_rand_bytes(64) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end

  defp random_b64(bytes), do: :crypto.strong_rand_bytes(bytes) |> Base.url_encode64(padding: false)

  defp open_in_browser(url) do
    cmd =
      case :os.type() do
        {:unix, :darwin} -> "open"
        {:unix, _} -> "xdg-open"
        {:win32, _} -> "start"
      end

    # Best-effort and async: on a headless devbox `xdg-open` may hang or
    # fail, so don't block the login flow on it.
    spawn(fn ->
      try do
        System.cmd(cmd, [url], stderr_to_stdout: true)
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  # Drives the listener loop in the main process while a side process
  # reads stdin. Whichever produces a result first wins.
  defp race_for_code(listen_socket, expected_state) do
    parent = self()
    paste_ref = make_ref()

    paste_pid =
      spawn(fn ->
        send(parent, {paste_ref, prompt_loop(expected_state)})
      end)

    result = poll_loop(listen_socket, expected_state, paste_ref)
    Process.exit(paste_pid, :kill)
    result
  end

  defp poll_loop(listen_socket, expected_state, paste_ref) do
    receive do
      {^paste_ref, result} -> result
    after
      0 ->
        case :gen_tcp.accept(listen_socket, 200) do
          {:ok, sock} ->
            handle_callback_socket(sock, expected_state)

          {:error, :timeout} ->
            poll_loop(listen_socket, expected_state, paste_ref)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp handle_callback_socket(sock, expected_state) do
    case read_request_path(sock) do
      {:ok, path} ->
        send_browser_response(sock, "Logged in. You can close this tab.")
        :gen_tcp.close(sock)
        parse_callback_query(URI.parse(path).query || "", expected_state)

      {:error, reason} ->
        :gen_tcp.close(sock)
        {:error, reason}
    end
  end

  defp prompt_loop(expected_state) do
    case IO.gets(:stdio, "paste redirect URL > ") do
      :eof ->
        {:error, :eof}

      {:error, reason} ->
        {:error, reason}

      input ->
        case String.trim(input) do
          "" ->
            prompt_loop(expected_state)

          url ->
            case parse_pasted_url(url, expected_state) do
              {:ok, _} = ok ->
                ok

              {:error, reason} ->
                IO.puts("Couldn't accept that URL (#{inspect(reason)}). Try again, or wait for the browser callback.")
                prompt_loop(expected_state)
            end
        end
    end
  end

  defp parse_pasted_url(url, expected_state) do
    case URI.parse(url) do
      %URI{query: q} when is_binary(q) and q != "" ->
        parse_callback_query(q, expected_state)

      _ ->
        {:error, "expected something like http://127.0.0.1:.../callback?code=...&state=..."}
    end
  end

  defp read_request_path(sock) do
    case :gen_tcp.recv(sock, 0, 5000) do
      {:ok, {:http_request, _method, {:abs_path, path}, _}} -> {:ok, to_string(path)}
      other -> {:error, other}
    end
  end

  defp send_browser_response(sock, body) do
    response =
      "HTTP/1.1 200 OK\r\n" <>
        "Content-Type: text/plain\r\n" <>
        "Content-Length: #{byte_size(body)}\r\n" <>
        "Connection: close\r\n\r\n" <>
        body

    :gen_tcp.send(sock, response)
  end

  defp parse_callback_query(query, expected_state) do
    decoded = URI.decode_query(query)

    cond do
      decoded["state"] != expected_state ->
        {:error, "state mismatch (possible CSRF)"}

      not is_binary(decoded["code"]) ->
        {:error, "no code in callback"}

      true ->
        {:ok, decoded["code"]}
    end
  end
end
