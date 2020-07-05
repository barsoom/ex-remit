# Provides a tabbed interface that avoids re-mounting LiveViews: https://elixirforum.com/t/tabbed-interface-with-multiple-liveviews/31670
defmodule RemitWeb.TabsLive do
  use RemitWeb, :live_view

  #@overlong_check_frequency_secs 60
  @overlong_check_frequency_secs 5

  @impl true
  def render(assigns) do
    ~L"""
    <div id="target-tabs"></div>

    <div style="display: <%= if @live_action == :commits, do: "block", else: "none" %>">
      <%= live_component @socket, RemitWeb.CommitsComponent, id: :commits, username: @username %>
    </div>

    <div style="display: <%= if @live_action == :comments, do: "block", else: "none" %>">
      <%# Using the params in the ID means it will be re-mounted if params change. %>
      <%= live_component @socket, RemitWeb.CommentsComponent, id: :comments, username: @username, params: comments_params(@params) %>
    </div>

    <div style="display: <%= if @live_action == :settings, do: "block", else: "none" %>">
      <%= live_component @socket, RemitWeb.SettingsComponent, id: :settings, username: @username %>
    </div>
    """
  end

  @impl true
  def mount(params, session, socket) do
    check_auth_key(session)

    if connected?(socket) do
      Remit.Commits.subscribe()
      Remit.Comments.subscribe()
      :timer.send_interval(@overlong_check_frequency_secs * 1000, self(), :check_for_overlong_reviewing)
    end

    {:ok, assign(socket, username: session["username"], params: params)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Since the child components run concurrently, they can't be relied on to set the title.
    socket =
      case socket.assigns.live_action do
        :commits ->
          assign(socket, page_title: "Commits")

        :comments ->
          assign(socket, page_title: "Comments", params: params)

        :settings ->
          assign(socket, page_title: "Settings")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("settings_form_change", %{"username" => username}, socket) do
    IO.inspect event: "settings_form_change", username: username
    {:noreply, assign(socket, username: Remit.Utils.normalize_string(username))}
  end

  # Received messages.
  # Because this is the topmost and only LiveView, and its subcomponents are not their own processes, all messages are received here and forwarded.

  # Runs periodically.
  def handle_info(:check_for_overlong_reviewing, socket) do
    update_commits(check_for_overlong_reviewing: true)
    {:noreply, socket}
  end

  # PubSub.
  @impl true
  def handle_info({:changed_commit, commit}, socket) do
    update_commits(changed_commit: commit)
    {:noreply, socket}
  end

  # PubSub.
  @impl true
  def handle_info({:new_commits, new_commits}, socket) do
    update_commits(new_commits: new_commits)
    {:noreply, socket}
  end

  # PubSub.
  @impl true
  def handle_info(:comments_changed, socket) do
    update_comments(comments_changed: true)
    {:noreply, socket}
  end

  defp update_commits(values) do
    RemitWeb.CommitsComponent
    |> send_update(Keyword.merge(values, id: :commits))
  end

  defp update_comments(values) do
    RemitWeb.CommentsComponent
    |> send_update(Keyword.merge(values, id: :comments))
  end

  defp comments_params(params) do
    Map.take(params, ["resolved", "user"])
  end
end
