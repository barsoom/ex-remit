import "phoenix_html"
import { Socket } from "phoenix"
import topbar from "../vendor/topbar"
import { LiveSocket } from "phoenix_live_view"


/* CLEAR FILTER PREFS ON LOGIN/LOGOUT TRANSITION */

// Filters are per-user. When the github user changes (login, logout, switch
// account), wipe filter prefs so the next user starts fresh.
;(() => {
  const FILTER_KEYS = ['remit:commit_filters', 'remit:comment_filters']
  const LAST_USER_KEY = 'remit:last_username'
  const current = document.body?.dataset.username ?? ''
  const last = localStorage.getItem(LAST_USER_KEY)
  if (last !== null && last !== current) {
    FILTER_KEYS.forEach(k => localStorage.removeItem(k))
  }
  localStorage.setItem(LAST_USER_KEY, current)
})()


/* LIVE SOCKET */

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

// - Fixes an issue where clicking a link with a phx-click on it did not cause the link default (navigation) to trigger.
// - Adds a target attribute to links when outside Fluid.app, so Remit stays open.
// - Makes it so that clicking buttons inside a link doesn't re-open it every time. (But clicking outside buttons opens it every time, so you can always navigate back to the commit/comment.)
// - Makes it so clicks in dev don't actually open links, unless inside Fluid.app, for convenience.
Hooks.FixLink = {
  mounted() {
    this.setTargetAttribute()

    this.el.addEventListener("click", (e) => {
      const didClickButton = !!e.target.closest("button")

      // If this is the last link we clicked, don't re-visit it on a button click. We'd reload the page (in Fluid) or open yet another tab (in a regular browser).
      if (window.remitLastClickedLink === this.el && didClickButton) {
        e.preventDefault()
        return
      }

      window.remitLastClickedLink = this.el

      // In dev outside Fluid.app, we typically care more about the Remit UI than opening links, so skip it.
      let isDev = (location.hostname === "localhost") || (location.hostname === "devbox")
      if (isDev && !window.fluid) {
        console.log("Skipping link opening in dev when outside Fluid.app. Link: ", this.el.href)
        e.preventDefault()
      }
    })
  },
  updated() {
    // After an update, the target attribute is lost. Re-set it.
    this.setTargetAttribute()
  },
  setTargetAttribute() {
    // Outside Fluid.app, in a regular browser, new tabs are less disruptive than opening in the same window.
    // In Fluid.app, we can't add a "target" attribute or they'd open in a new tab instead of in the main window next to the Remit panel.
    // We use a named target rather than "_blank" so it's reused. This means you put the opened window side-by-side with Remit and have a halfway decent Fluid-like experience.
    if (!window.fluid) this.el.setAttribute("target", "github_window")
  }
}

Hooks.ScrollToTarget = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      let id = this.el.href.split("#")[1]
      e.preventDefault()

      // `block: "center"` because the default `"start"` means it's likely to end up right under a sticky date header.
      document.getElementById(id).scrollIntoView({ block: "center" })
    })
  }
}

Hooks.Logout = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      fetch(`/api/logout`, { method: "post" })
      localStorage.removeItem('remit:commit_filters')
      localStorage.removeItem('remit:comment_filters')
      localStorage.removeItem('remit:last_username')
    })
  }
}

Hooks.UpdateGithubTeams = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      fetch(`/api/update_github_teams`, { method: "post" })
    })
  }
}

Hooks.CancelDefaultNavigation = {
  mounted() {
    this.el.addEventListener("click", (e) => e.preventDefault());
  }
}

Hooks.FilterLink = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault();
      const dataset = e.target.dataset;
      const body = {
        param: dataset.filterParam,
        value: dataset.filterValue,
      }
      fetch(`/api/filter_preference/${dataset.filterScope}`, { method: "post", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) })
    })
  }
}

Hooks.SetReviewedCommitCutoff = {
  mounted() {
    this.el.addEventListener("change", (e) => {
      console.log(e.target.name, e.target.value);
      const formData = new FormData();
      formData.append(e.target.name, e.target.value);
      fetch(`/api/reviewed_commit_cutoff`, { method: "post", body: formData })
    })
  }
}

// Shared behaviour for CommitSearch and CommentSearch. Spread in via Object.assign so `this`
// refers to the hook instance, giving access to this.el and the hook's own closeAllDropdowns.
const FilterHookMixin = {
  destroyed() {
    document.removeEventListener('click', this._closeDropdown)
  },

  // Call from mounted() — adds a document listener that closes all dropdowns on outside clicks.
  // Pass any extra selectors whose clicks should NOT close dropdowns (e.g. '[data-repo-dropdown]').
  setupOutsideClickHandler(...keepOpenSelectors) {
    this._closeDropdown = (e) => {
      if (!['[data-filter-dropdown]', ...keepOpenSelectors].some(sel => e.target.closest(sel)))
        this.closeAllDropdowns()
    }
    document.addEventListener('click', this._closeDropdown)
  },

  // Call from mounted() — adds a click listener on this.el for [data-filter-dropdown-toggle] buttons.
  setupFilterClickHandler() {
    this.el.addEventListener('click', (e) => {
      const filterToggle = e.target.closest('[data-filter-dropdown-toggle]')
      if (filterToggle) {
        e.stopPropagation()
        this.toggleFilterDropdown(filterToggle)
      }
    })
  },

  updateLabel(sel, set, defaultText) {
    const el = this.el.querySelector(sel)
    if (!el) return
    const count = set.size
    el.textContent = count === 0 ? defaultText : count === 1 ? [...set][0] : `${count} selected`
  },

  toggleFilterDropdown(filterToggle) {
    const dropdown = filterToggle.closest('[data-filter-dropdown]')
    const panel = dropdown?.querySelector('[data-filter-dropdown-panel]')
    const chevron = filterToggle.querySelector('[data-filter-chevron]')
    const isOpen = !panel?.classList.contains('hidden')
    this.closeAllDropdowns()
    if (!isOpen) { panel?.classList.remove('hidden'); chevron?.classList.add('rotate-180') }
  },
}

// Both search hooks below drive *server-side* filtering: the checkbox/radio/search state is read
// from the server-rendered DOM, pushed back to the LiveView as a `set_filters` event, and persisted
// to the session so the next first render is already correct. Nothing is filtered in the browser —
// doing that would only ever hide rows from the page the server already limited, so filtered-out
// older matches could never be reached.
const ServerFilterMixin = {
  // Persist one param to the session, same endpoint the legacy filter links use.
  persist(param, value) {
    fetch(`/api/filter_preference/${this.filterScope}`, {
      method: 'post',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ param, value }),
    })
  },

  setsFromDom(specs) {
    const out = {}
    for (const [key, selector, attr] of specs) {
      out[key] = new Set(
        Array.from(this.el.querySelectorAll(selector))
          .filter(cb => cb.checked)
          .map(cb => cb.dataset[attr])
      )
    }
    return out
  },

  radioFromDom(selector, attr, fallback) {
    const checked = Array.from(this.el.querySelectorAll(selector)).find(r => r.checked)
    return checked ? checked.dataset[attr] : fallback
  },

  // Debounced so typing doesn't fire a query per keystroke.
  debouncedPush(fn, ms = 250) {
    clearTimeout(this._pushTimer)
    this._pushTimer = setTimeout(fn, ms)
  },
}

Hooks.CommitSearch = Object.assign({}, FilterHookMixin, ServerFilterMixin, {
  filterScope: 'commits',

  mounted() {
    this.readState()

    const searchInput = this.el.querySelector('[data-commit-search]')
    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        this.searchQuery = e.target.value
        this.debouncedPush(() => {
          this.persist('search', this.searchQuery)
          this.pushFilters()
        })
      })
    }

    this.el.addEventListener('click', (e) => {
      if (e.target.closest('[data-repo-dropdown-toggle]')) {
        e.stopPropagation()
        this.toggleDropdown('[data-repo-dropdown-panel]', '[data-repo-dropdown-chevron]')
      }
    })
    this.setupFilterClickHandler()

    this.el.addEventListener('change', (e) => {
      const cb = e.target
      if (!cb.matches('input[type="checkbox"], input[type="radio"]')) return

      if ('reposAll' in cb.dataset) return this.clearGroup('[data-repos-value]', 'repos')
      if ('reposValue' in cb.dataset) return this.toggleGroup('repos', 'selectedRepos', cb.dataset.reposValue, cb.checked, '[data-repos-all]')
      if ('authorsAll' in cb.dataset) return this.clearGroup('[data-authors-value]', 'authors')
      if ('authorsValue' in cb.dataset) return this.toggleGroup('authors', 'selectedAuthors', cb.dataset.authorsValue, cb.checked, '[data-authors-all]')
      if ('projectsAll' in cb.dataset) return this.clearGroup('[data-projects-team]', 'project_teams')
      if ('projectsTeam' in cb.dataset) return this.toggleGroup('project_teams', 'selectedProjectTeams', cb.dataset.projectsTeam, cb.checked, '[data-projects-all]')
      if ('membersAll' in cb.dataset) return this.clearGroup('[data-members-team]', 'member_teams')
      if ('membersTeam' in cb.dataset) return this.toggleGroup('member_teams', 'selectedMemberTeams', cb.dataset.membersTeam, cb.checked, '[data-members-all]')
      if ('statusValue' in cb.dataset) {
        this.reviewedFilter = cb.dataset.statusValue
        this.persist('reviewed', this.reviewedFilter)
        this.onFilterChange()
      }
    })

    this.setupOutsideClickHandler('[data-repo-dropdown]')

    this.syncLabels()
    this.syncButtonStates()
  },

  updated() {
    // The server just re-rendered the bar with authoritative state; re-read rather than trusting
    // our local copy, so the two can never drift.
    this.readState()
    this.syncLabels()
    this.syncButtonStates()
  },

  readState() {
    const sets = this.setsFromDom([
      ['repos', '[data-repos-value]', 'reposValue'],
      ['authors', '[data-authors-value]', 'authorsValue'],
      ['projectTeams', '[data-projects-team]', 'projectsTeam'],
      ['memberTeams', '[data-members-team]', 'membersTeam'],
    ])
    this.selectedRepos = sets.repos
    this.selectedAuthors = sets.authors
    this.selectedProjectTeams = sets.projectTeams
    this.selectedMemberTeams = sets.memberTeams
    this.reviewedFilter = this.radioFromDom('[data-status-value]', 'statusValue', 'all')
    const searchInput = this.el.querySelector('[data-commit-search]')
    this.searchQuery = searchInput ? searchInput.value : ''
  },

  clearGroup(itemSelector, param) {
    this.el.querySelectorAll(itemSelector).forEach(cb => { cb.checked = false })
    this.readState()
    this.persist(param, [])
    this.onFilterChange()
  },

  toggleGroup(param, stateKey, value, checked, allSelector) {
    checked ? this[stateKey].add(value) : this[stateKey].delete(value)
    this.el.querySelectorAll(allSelector).forEach(cb => { cb.checked = this[stateKey].size === 0 })
    this.persist(param, [...this[stateKey]])
    this.onFilterChange()
  },

  onFilterChange() {
    this.syncLabels()
    this.syncButtonStates()
    this.pushFilters()
  },

  pushFilters() {
    this.pushEvent('set_filters', {
      repos: [...this.selectedRepos],
      authors: [...this.selectedAuthors],
      project_teams: [...this.selectedProjectTeams],
      member_teams: [...this.selectedMemberTeams],
      reviewed: this.reviewedFilter,
      search: this.searchQuery,
    })
  },

  toggleDropdown(panelSel, chevronSel) {
    const panel = this.el.querySelector(panelSel)
    const chevron = this.el.querySelector(chevronSel)
    const isOpen = !panel?.classList.contains('hidden')
    this.closeAllDropdowns()
    if (!isOpen) { panel?.classList.remove('hidden'); chevron?.classList.add('rotate-180') }
  },

  closeAllDropdowns() {
    this.el.querySelectorAll('[data-repo-dropdown-panel], [data-filter-dropdown-panel]').forEach(p => p.classList.add('hidden'))
    this.el.querySelectorAll('[data-repo-dropdown-chevron], [data-filter-dropdown-toggle] [data-filter-chevron]').forEach(c => c.classList.remove('rotate-180'))
  },

  syncLabels() {
    this.updateLabel('[data-author-label]', this.selectedAuthors, 'By')
    this.updateLabel('[data-repo-dropdown-label]', this.selectedRepos, 'Repo')
    this.updateLabel('[data-projects-label]', this.selectedProjectTeams, 'Projects')
    this.updateLabel('[data-members-label]', this.selectedMemberTeams, 'Members')

    const statusLabels = { 'all': 'Status', 'unreviewed': 'Unreviewed', 'reviewed': 'Reviewed' }
    const statusLabelEl = this.el.querySelector('[data-status-label]')
    if (statusLabelEl) statusLabelEl.textContent = statusLabels[this.reviewedFilter] || 'Status'
  },

  syncButtonStates() {
    ;[
      ['[data-author-active]', this.selectedAuthors],
      ['[data-projects-active]', this.selectedProjectTeams],
      ['[data-members-active]', this.selectedMemberTeams],
      ['[data-repo-active]', this.selectedRepos],
    ].forEach(([sel, set]) => {
      this.el.querySelectorAll(sel).forEach(dot => dot.classList.toggle('hidden', set.size === 0))
    })
    this.el.querySelectorAll('[data-status-active]').forEach(dot => dot.classList.toggle('hidden', this.reviewedFilter === 'all'))
  },
})

Hooks.CommentSearch = Object.assign({}, FilterHookMixin, ServerFilterMixin, {
  filterScope: 'comments',

  mounted() {
    this.readState()

    const searchInput = this.el.querySelector('[data-comment-search]')
    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        this.searchQuery = e.target.value
        this.debouncedPush(() => {
          this.persist('search', this.searchQuery)
          this.pushFilters()
        })
      })
    }

    this.setupFilterClickHandler()

    this.el.addEventListener('change', (e) => {
      const input = e.target
      if (!input.matches('input[type="radio"]')) return

      if ('commentStatusValue' in input.dataset) {
        this.resolvedFilter = input.dataset.commentStatusValue
        this.persist('is', this.resolvedFilter)
        this.onFilterChange()
      } else if ('commentRoleValue' in input.dataset) {
        this.roleFilter = input.dataset.commentRoleValue
        this.persist('role', this.roleFilter)
        this.onFilterChange()
      }
    })

    this.setupOutsideClickHandler()

    this.syncLabels()
    this.syncButtonStates()
  },

  updated() {
    this.readState()
    this.syncLabels()
    this.syncButtonStates()
  },

  readState() {
    this.resolvedFilter = this.radioFromDom('[data-comment-status-value]', 'commentStatusValue', 'all')
    this.roleFilter = this.radioFromDom('[data-comment-role-value]', 'commentRoleValue', 'all')
    const searchInput = this.el.querySelector('[data-comment-search]')
    this.searchQuery = searchInput ? searchInput.value : ''
  },

  closeAllDropdowns() {
    this.el.querySelectorAll('[data-filter-dropdown-panel]').forEach(p => p.classList.add('hidden'))
    this.el.querySelectorAll('[data-filter-dropdown-toggle] [data-filter-chevron]').forEach(c => c.classList.remove('rotate-180'))
  },

  onFilterChange() {
    this.syncLabels()
    this.syncButtonStates()
    this.pushFilters()
  },

  pushFilters() {
    this.pushEvent('set_filters', {
      is: this.resolvedFilter,
      role: this.roleFilter,
      search: this.searchQuery,
    })
  },

  syncLabels() {
    const statusLabels = { 'unresolved': 'Unresolved', 'resolved': 'Resolved', 'all': 'All comments' }
    const statusLabelEl = this.el.querySelector('[data-comment-status-label]')
    if (statusLabelEl) statusLabelEl.textContent = statusLabels[this.resolvedFilter] || 'Status'

    const roleLabels = { 'for_me': 'For me', 'by_me': 'By me', 'all': 'For anyone' }
    const roleLabelEl = this.el.querySelector('[data-comment-role-label]')
    if (roleLabelEl) roleLabelEl.textContent = roleLabels[this.roleFilter] || 'Role'
  },

  syncButtonStates() {
    this.el.querySelectorAll('[data-comment-status-active]').forEach(dot => dot.classList.toggle('hidden', this.resolvedFilter === 'all'))
    this.el.querySelectorAll('[data-comment-role-active]').forEach(dot => dot.classList.toggle('hidden', this.roleFilter === 'all'))
  },
})


Hooks.FeatureToggle = {
  mounted() {
    this.el.addEventListener('change', (e) => {
      const checkbox = e.target.closest('input[type="checkbox"][phx-value-feature]')
      if (!checkbox) return
      this.saveFeature(checkbox.getAttribute('phx-value-feature'), checkbox.checked)
    })

    this.el.addEventListener('click', (e) => {
      const switchButton = e.target.closest('button[role="switch"][phx-value-feature]')
      if (switchButton) {
        // aria-checked reflects pre-click state; invert it for the new state
        this.saveFeature(switchButton.getAttribute('phx-value-feature'), switchButton.getAttribute('aria-checked') !== 'true')
        return
      }
      const setButton = e.target.closest('button[phx-value-feature][phx-value-enabled]')
      if (setButton) {
        this.saveFeature(setButton.getAttribute('phx-value-feature'), setButton.getAttribute('phx-value-enabled') === 'true')
      }
    })
  },
  saveFeature(feature, enabled) {
    const formData = new FormData()
    formData.append('feature', feature)
    formData.append('enabled', enabled)
    fetch('/api/features', { method: 'post', body: formData })
  }
}

document.addEventListener('click', (e) => {
  const deployedEl = e.target.closest('[data-deployed-url]')
  if (deployedEl?.dataset.deployedUrl) {
    e.stopPropagation()
    e.preventDefault()
    window.open(deployedEl.dataset.deployedUrl, window.fluid ? '_self' : 'github_window')
    return
  }

  const btn = e.target.closest('[data-clipboard-copy]')
  if (!btn) return
  e.stopPropagation()
  e.preventDefault()
  const text = btn.dataset.clipboardCopy
  const icon = btn.querySelector('i')
  const confirm = () => {
    if (!icon) return
    const orig = icon.className
    icon.className = orig.replace('fa-copy', 'fa-check').replace('fa-link', 'fa-check')
    setTimeout(() => { icon.className = orig }, 1000)
  }
  if (navigator.clipboard?.writeText) {
    navigator.clipboard.writeText(text).then(confirm).catch(() => fallbackCopy(text, confirm))
  } else {
    fallbackCopy(text, confirm)
  }
}, true)

function fallbackCopy(text, done) {
  const ta = Object.assign(document.createElement('textarea'), { value: text })
  Object.assign(ta.style, { position: 'fixed', opacity: '0' })
  document.body.appendChild(ta)
  ta.select()
  document.execCommand('copy')
  document.body.removeChild(ta)
  done?.()
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
})

window.addEventListener('phx:feature-flags-updated', (e) => {
  document.documentElement.classList.toggle('dark', !!e.detail.dark_theme)
})

// Show progress bar on live navigation and form submits.
let pingOfflineTimeout = null
let disconnectedAt = null

window.addEventListener("phx:page-loading-start", (info) => {
  topbar.show(100)
  if (info?.detail?.kind === "error") {
    disconnectedAt = Date.now()
    // Wait to be sure it's a disconnect and not a page reload.
    pingOfflineTimeout = setTimeout(function () {
      pingOfflineTimeout = null
      document.body.classList.add("ping-offline")
    }, 100)
  }
})

window.addEventListener("phx:page-loading-stop", (_info) => {
  // Cancel the pending banner if we reconnect before the delay fires.
  if (pingOfflineTimeout) {
    clearTimeout(pingOfflineTimeout)
    pingOfflineTimeout = null
  }

  const disconnectDuration = disconnectedAt ? Date.now() - disconnectedAt : 0
  disconnectedAt = null

  // After a long disconnect (e.g. sleep), reload to get fresh state instead of trusting LiveView to patch a potentially stale page.
  if (disconnectDuration > 10000) {
    location.reload()
    return
  }

  document.body.classList.remove("ping-offline")
  topbar.hide()
})

topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket

let authKey = document.querySelector("meta[name='auth_key']").getAttribute("content")
let socket = new Socket("/socket", { params: { auth_key: authKey }, heartbeatIntervalMs: 15000 })
socket.connect()
