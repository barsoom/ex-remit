defmodule RemitWeb.SettingsLive do
  use RemitWeb, :live_view
  require Logger
  alias Remit.{GithubAuth, Ownership}

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    check_auth_key(session)

    if connected?(socket) do
      GithubAuth.subscribe(session["session_id"])
      Ownership.subscribe()
    end

    socket
    |> assign(username: github_login(session))
    |> assign_projects()
    |> assign_teams()
    |> ok()
  end

  @impl Phoenix.LiveView
  def handle_event("add_project_owner", %{"project" => project, "team" => team}, socket) do
    Remit.Team.add_project(team, project)
    noreply(socket)
  end

  def handle_event("remove_project_owner", %{"project" => project, "team" => team}, socket) do
    Remit.Team.remove_project(team, project)
    noreply(socket)
  end

  @impl Phoenix.LiveView
  def handle_event(event, _, socket) do
    Logger.error("unexpected event #{event}")
    noreply(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:login, %Remit.Github.User{login: login}}, socket) do
    socket
    |> assign(:username, login)
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_info(:logout, socket) do
    socket
    |> assign(:username, nil)
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_info(:ownership_changed, socket) do
    socket
    |> assign_projects()
    |> assign_teams()
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_info(message, socket) do
    Logger.error("unexpected message #{inspect(message)}")
    {:noreply, socket}
  end

  defp assign_projects(socket) do
    socket
    |> assign(projects: Remit.Project.get_all())
  end

  defp assign_teams(socket) do
    socket
    |> assign(teams: Remit.Team.get_all())
  end

  defp projects(assigns) do
    ~H"""
    <div class="bg-gray-200 px-3 py-4 mt-6">
      <h2 class="font-semibold text-xs mb-2 uppercase">Project ownership</h2>
      <%= for {project, project_teams} <- @projects do %>
        <.project project={project} project_teams={project_teams} teams={@teams} />
      <% end %>
    </div>
    """
  end

  defp project(assigns) do
    ~H"""
    <div class="mb-1">
      <div class="flex">
        <span class="flex-1 font-semibold"><%= @project %></span>
        <.team_dropdown project={@project} teams={@teams -- @project_teams} />
      </div>
      <.teams project={@project} teams={@project_teams} />
    </div>
    """
  end

  defp team_dropdown(%{teams: []} = assigns), do: ~H""

  defp team_dropdown(assigns) do
    ~H"""
    <.form for={:project} phx-submit="add_project_owner">
      <input type="hidden" name="project" value={@project} />
      <select name="team">
        <%= for team <- @teams do %>
          <option value={team.slug}><%= team.name %></option>
        <% end %>
      </select>
      <%= submit("add owner") %>
    </.form>
    """
  end

  defp teams(%{teams: []} = assigns) do
    ~H"""
    <span class="text-red-700 ml-3">unclaimed</span>
    """
  end

  defp teams(assigns) do
    ~H"""
    <ul>
      <%= for team <- @teams do %>
        <.form for={:project} phx-submit="remove_project_owner">
          <input type="hidden" name="project" value={@project} />
          <input type="hidden" name="team" value={team.slug} />
          <li class="ml-3"><%= team.name %><%= submit("remove", class: "ml-2") %></li>
        </.form>
      <% end %>
    </ul>
    """
  end
end
