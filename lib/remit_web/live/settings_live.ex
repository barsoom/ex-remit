defmodule RemitWeb.SettingsLive do
  use RemitWeb, :live_view
  require Logger
  alias Remit.{GithubAuth, Ownership, Settings}
  import Phoenix.HTML.{Form, Link}

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    check_auth_key(session)
    features = get_feature_flags(session)

    if connected?(socket) do
      GithubAuth.subscribe(session["session_id"])
      Ownership.subscribe()
    end

    socket
    |> assign(session_id: session["session_id"])
    |> assign(username: github_login(session))
    |> assign_projects()
    |> assign_teams()
    |> assign(reviewed_commit_cutoff: get_reviewed_commit_cutoff(session, %{"days" => 7, "commits" => 100}))
    |> assign(features: features)
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

  def handle_event("toggle_feature", %{"feature" => feature}, socket) do
    new_flags = Map.update(socket.assigns.features, feature, false, &(!&1))
    Settings.broadcast(session_id(socket), :feature_flags, new_flags)

    socket
    |> assign(features: new_flags)
    |> push_event("feature-flags-updated", new_flags)
    |> noreply()
  end

  def handle_event("set_feature", %{"feature" => feature, "enabled" => enabled}, socket) do
    new_flags = Map.put(socket.assigns.features, feature, enabled == "true")
    Settings.broadcast(session_id(socket), :feature_flags, new_flags)

    socket
    |> assign(features: new_flags)
    |> push_event("feature-flags-updated", new_flags)
    |> noreply()
  end

  def handle_event(
        "update_reviewed_commit_cutoff",
        %{"reviewed_commit_cutoff" => %{"days" => days, "commits" => commits}},
        socket
      ) do
    Settings.broadcast(session_id(socket), :reviewed_commit_cutoff, %{
      "days" => String.to_integer(days),
      "commits" => String.to_integer(commits)
    })

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

  defp toggle_preference(assigns) do
    ~H"""
    <label class="flex items-start gap-3 cursor-pointer select-none">
      <div class="relative block w-11 h-6 mt-0.5 shrink-0">
        <input
          type="checkbox"
          checked={@enabled}
          phx-click="toggle_feature"
          phx-value-feature={@feature}
          class="sr-only peer"
        />
        <span class="block h-6 w-11 rounded-full bg-gray-300 peer-checked:bg-blue-600 transition-colors duration-200">
        </span>
        <span class="absolute left-0.5 top-0.5 h-5 w-5 rounded-full bg-gray-50 shadow transition-transform duration-200 peer-checked:translate-x-5">
        </span>
      </div>
      <div class="flex-1 min-w-0">
        <span class="leading-none font-bold"><%= @label %></span>
        <p class="text-xs text-gray-mid mt-0.5"><%= @description %></p>
      </div>
    </label>
    """
  end

  defp feature_toggle(assigns) do
    ~H"""
    <label class={[
      "flex items-start gap-3 select-none",
      if(assigns[:opt_in], do: "cursor-pointer", else: "cursor-not-allowed opacity-50")
    ]}>
      <div class="relative block w-11 h-6 mt-0.5 shrink-0">
        <input
          type="checkbox"
          checked={@enabled}
          phx-click="toggle_feature"
          phx-value-feature={@feature}
          class="sr-only peer"
          disabled={!assigns[:opt_in]}
        />
        <span class="block h-6 w-11 rounded-full bg-gray-300 peer-checked:bg-blue-600 transition-colors duration-200">
        </span>
        <span class="absolute left-0.5 top-0.5 h-5 w-5 rounded-full bg-gray-50 shadow transition-transform duration-200 peer-checked:translate-x-5">
        </span>
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2">
          <span class="leading-none font-bold"><%= @label %></span>
          <%= if assigns[:todo] do %>
            <span class="text-xs text-yellow-600 bg-yellow-100 px-1.5 py-0.5 rounded" title="Work in progress">🚧 WIP</span>
          <% end %>
        </div>
        <p class="text-xs text-gray-mid mt-0.5"><%= @description %></p>
      </div>
    </label>
    """
  end

  defp theme_toggle(assigns) do
    ~H"""
    <div class="relative block w-11 h-6 cursor-pointer select-none">
      <input
        type="checkbox"
        checked={@dark?}
        phx-click="toggle_feature"
        phx-value-feature="dark_theme"
        class="sr-only peer"
      />
      <%!-- Track --%>
      <span class="block h-6 w-11 rounded-full bg-gray-300 dark:bg-gray-600 peer-checked:bg-blue-600 transition-colors duration-200">
      </span>
      <%!-- Thumb --%>
      <span class="absolute left-0.5 top-0.5 h-5 w-5 rounded-full bg-gray-50 shadow transition-transform duration-200 peer-checked:translate-x-5">
      </span>
      <%!-- Moon icon (visible when dark theme on) --%>
      <span class="absolute left-1.5 top-1.5 hidden peer-checked:block text-white" style="font-size: 10px; line-height: 1;">
        <i class="fas fa-moon"></i>
      </span>
      <%!-- Sun icon (visible when dark theme off) --%>
      <span
        class="absolute right-1.5 top-1.5 block peer-checked:hidden text-amber-500"
        style="font-size: 10px; line-height: 1;"
      >
        <i class="fas fa-sun"></i>
      </span>
    </div>
    """
  end

  defp assign_projects(socket) do
    socket
    |> assign(projects: Remit.Project.get_all())
  end

  defp assign_teams(socket) do
    socket
    |> assign(teams: Remit.Team.get_all())
  end

  defp session_id(socket), do: socket.assigns.session_id

  defp projects(assigns) do
    ~H"""
    <div class={["bg-gray-100 dark:bg-gray-800 px-3 py-4 mt-6", @compact && "rounded-xl shadow-sm"]}>
      <h2 class="font-semibold text-xs mb-2 uppercase">Project ownership</h2>
      <%= if @compact do %>
        <div class="divide-y divide-gray-300 dark:divide-gray-600">
          <%= for {project, project_teams} <- @projects do %>
            <.project_row project={project} project_teams={project_teams} all_teams={@teams} />
          <% end %>
        </div>
      <% else %>
        <%= for {project, project_teams} <- @projects do %>
          <.project project={project} project_teams={project_teams} teams={@teams} />
        <% end %>
      <% end %>
    </div>
    """
  end

  defp project_row(assigns) do
    ~H"""
    <% available_teams = @all_teams -- @project_teams %>
    <div class="flex items-center gap-3 py-2 min-h-[2rem]">
      <span class="font-semibold text-xs w-32 shrink-0"><%= @project %></span>
      <div class="flex flex-wrap gap-1 flex-1 min-w-0">
        <%= if @project_teams == [] do %>
          <span class="text-red-600 text-xs italic">unclaimed</span>
        <% else %>
          <%= for team <- @project_teams do %>
            <span class="inline-flex items-center gap-1 pl-2 pr-1.5 py-0.5 text-xs bg-gray-700 dark:bg-gray-600 text-white rounded-full select-none">
              <%= team.name %>
              <span
                phx-click="remove_project_owner"
                phx-value-project={@project}
                phx-value-team={team.slug}
                class="cursor-pointer text-gray-400 hover:text-white leading-none"
              >
                ×
              </span>
            </span>
          <% end %>
        <% end %>
      </div>
      <%= if available_teams != [] do %>
        <.form for={%{}} as={:project} phx-submit="add_project_owner" class="flex items-center gap-1 shrink-0">
          <input type="hidden" name="project" value={@project} />
          <select name="team" class="text-xs h-5 py-0">
            <%= for team <- available_teams do %>
              <option value={team.slug}><%= team.name %></option>
            <% end %>
          </select>
          <%= submit("Add", class: "text-xs h-5 px-2 py-0") %>
        </.form>
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
    <.form for={%{}} as={:project} phx-submit="add_project_owner">
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
        <.form for={%{}} as={:project} phx-submit="remove_project_owner">
          <input type="hidden" name="project" value={@project} />
          <input type="hidden" name="team" value={team.slug} />
          <li class="ml-3"><%= team.name %><%= submit("remove", class: "ml-2") %></li>
        </.form>
      <% end %>
    </ul>
    """
  end
end
