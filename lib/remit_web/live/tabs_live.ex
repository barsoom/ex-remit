# Provides a tabbed interface that avoids re-mounting LiveViews.
# Read more: https://elixirforum.com/t/tabbed-interface-with-multiple-liveviews/31670
defmodule RemitWeb.TabsLive do
  use RemitWeb, :live_view
  alias Remit.{Comments, GithubAuth, Settings}

  defp default_tabs do
    [
      %{
        action: :commits,
        url: ~p"/commits",
        module: RemitWeb.CommitsLive,
        text: "Commits",
        icon: "fa-eye",
        has_notification: false
      },
      %{
        action: :comments,
        url: ~p"/comments",
        module: RemitWeb.CommentsLive,
        text: "Comments",
        icon: "fa-comments",
        has_notification: false,
        notification_count: nil
      },
      %{
        action: :settings,
        url: ~p"/settings",
        module: RemitWeb.SettingsLive,
        text: "Settings",
        icon: "fa-cog",
        has_notification: false
      }
    ]
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <%= for tab <- @tabs do %>
      <div style={"display: #{if @live_action == tab.action, do: "block", else: "none"}"}>
        <%= live_render(@socket, tab.module, id: tab.action) %>
      </div>
    <% end %>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    check_auth_key(session)
    socket = assign(socket, tabs: default_tabs())

    if connected?(socket) do
      Comments.subscribe()
      GithubAuth.subscribe(session["session_id"])
      Settings.subscribe(session["session_id"])
    end

    socket
    |> assign_username(github_login(session))
    |> assign_default_params(session)
    |> assign(inbox_count_badge: get_feature_flags(session)["inbox_count_badge"])
    |> assign(compact_design: get_feature_flags(session)["compact_design"])
    |> assign_tab_notification()
    |> ok()
  end

  @impl Phoenix.LiveView
  def handle_info(:comments_changed, socket) do
    socket |> assign_tab_notification() |> noreply()
  end

  def handle_info({:setting_updated, :feature_flags, flags}, socket) do
    socket
    |> assign(inbox_count_badge: flags["inbox_count_badge"])
    |> assign(compact_design: flags["compact_design"])
    |> assign_tab_notification()
    |> noreply()
  end

  def handle_info({:login, %Remit.Github.User{login: login}}, socket) do
    socket |> assign_username(login) |> assign_tab_notification() |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    # Since the child LiveViews run concurrently, they can't be relied on to set the title themselves.
    socket |> assign_page_title() |> noreply()
  end

  # Private
  defp assign_page_title(%{assigns: %{live_action: action}} = socket) do
    assign(socket, page_title: page_title(action))
  end

  # Use the same value for the tab text and the page title.
  defp page_title(action) do
    default_tabs()
    # O(n) but it will never be long enough to matter
    |> Enum.find(&(&1.action == action))
    |> Map.get(:text)
  end

  defp assign_username(socket, username) do
    socket
    |> assign(username: username)
  end

  defp assign_default_params(socket, session) do
    assign(socket,
      is: get_filter(session, "comments", "is", "unresolved"),
      role: get_filter(session, "comments", "role", if(socket.assigns.username, do: "for_me", else: "all"))
    )
  end

  defp assign_tab_notification(socket) do
    tabs =
      default_tabs()
      |> Enum.map(fn tab -> update_tab_state(socket, tab) end)

    assign(socket, tabs: tabs)
  end

  defp update_tab_state(socket, %{:action => :comments} = tab) do
    if socket.assigns.inbox_count_badge do
      count =
        Comments.list_notifications(
          limit: 99,
          username: socket.assigns.username,
          resolved_filter: "unresolved",
          user_filter: socket.assigns.role
        )
        |> length()

      %{tab | has_notification: count > 0, notification_count: count}
    else
      has_notification =
        Comments.list_notifications(
          limit: 1,
          username: socket.assigns.username,
          resolved_filter: socket.assigns.is,
          user_filter: socket.assigns.role
        )
        |> Enum.any?()

      %{tab | has_notification: has_notification, notification_count: nil}
    end
  end

  defp update_tab_state(_socket, tab), do: tab
end
