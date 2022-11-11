defmodule Remit.GithubAuth do
  @moduledoc false
  use GenServer

  defstruct [
    tokens: %{},
  ]

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def create_state_token, do: GenServer.call(__MODULE__, :create_state_token)

  def verify_and_destroy_state_token(token), do: GenServer.call(__MODULE__, {:verify_and_destroy_state_token, token})

  def delete_old_tokens, do: GenServer.cast(__MODULE__, :delete_old_tokens)

  def auth_url(token) do
    client_id = Remit.Config.github_oauth_client_id
    "https://github.com/login/oauth/authorize?client_id=#{client_id}&state=#{token}"
  end

  def get_access_token(code) do
    request = %{
      "client_id" => Remit.Config.github_oauth_client_id(),
      "client_secret" => Remit.Config.github_oauth_client_secret(),
      "code" => code,
    }
    {:ok, %{body: data}} = Tesla.post(tesla_client(), "/login/oauth/access_token", request)
    data["access_token"]
  end

  ### GenServer

  def init(_), do: {:ok, %__MODULE__{}}

  def handle_call(:create_state_token, _from, %__MODULE__{tokens: tokens} = state) do
    token = generate()
    state = %__MODULE__{state | tokens: Map.put(tokens, token, Time.utc_now())}
    {:reply, token, state}
  end

  def handle_call({:verify_and_destroy_state_token, token}, _from, %__MODULE__{tokens: tokens} = state) do
    if Map.has_key?(tokens, token) do
      state = %__MODULE__{state | tokens: Map.delete(tokens, token)}
      {:reply, true, state}
    else
      {:reply, false, state}
    end
  end

  # 10 minutes matches the github expiration
  @stale_threshold 60 * 10

  def handle_cast(:delete_old_tokens, %__MODULE__{tokens: tokens} = state) do
    now = Time.utc_now()
    tokens = Map.reject(tokens, fn {_, time} -> Time.diff(now, time) > @stale_threshold end)
    {:noreply, %__MODULE__{state | tokens: tokens}}
  end

  ### Private

  @token_alphabet '0123456789abcdef'
  @token_length 16

  defp generate do
    symbol_count = Enum.count(@token_alphabet)
    for _ <- 1..@token_length, into: "", do: <<Enum.at(@token_alphabet, :rand.uniform(symbol_count)-1)>>
  end

  defp tesla_client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, "https://github.com"},
      {Tesla.Middleware.Headers, tesla_headers()},
      Tesla.Middleware.JSON
    ])
  end

  defp tesla_headers do
    [
      {"accept", "application/json"},
    ]
  end
end
