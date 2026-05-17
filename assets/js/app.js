import "phoenix_html"
import { Socket } from "phoenix"
import topbar from "../vendor/topbar"
import { LiveSocket } from "phoenix_live_view"


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

Hooks.CommitSearch = {
  storageKey: 'remit:commit_filters',

  mounted() {
    this.loadPreferences()

    const searchInput = this.el.querySelector('[data-commit-search]')
    if (searchInput) {
      if (this.searchQuery) searchInput.value = this.searchQuery
      searchInput.addEventListener('input', (e) => {
        this.searchQuery = e.target.value.toLowerCase()
        this.savePreferences()
        this.filterCommits()
      })
    }

    // Dropdown toggle via event delegation (survives LiveView updates)
    this.el.addEventListener('click', (e) => {
      if (e.target.closest('[data-repo-dropdown-toggle]')) {
        e.stopPropagation()
        this.toggleDropdown('[data-repo-dropdown-panel]', '[data-repo-dropdown-chevron]')
        return
      }
      const filterToggle = e.target.closest('[data-filter-dropdown-toggle]')
      if (filterToggle) {
        e.stopPropagation()
        const dropdown = filterToggle.closest('[data-filter-dropdown]')
        const panel = dropdown?.querySelector('[data-filter-dropdown-panel]')
        const chevron = filterToggle.querySelector('[data-filter-chevron]')
        const isOpen = !panel?.classList.contains('hidden')
        this.closeAllDropdowns()
        if (!isOpen) { panel?.classList.remove('hidden'); chevron?.classList.add('rotate-180') }
        return
      }
    })

    // Checkbox changes via event delegation
    this.el.addEventListener('change', (e) => {
      const cb = e.target
      if (!cb.matches('input[type="checkbox"], input[type="radio"]')) return

      if ('projectsAll' in cb.dataset) { this.clearSet(this.selectedProjectTeams, '[data-projects-team]'); this.onFilterChange(); return }
      if ('projectsTeam' in cb.dataset) { this.toggleInSet(this.selectedProjectTeams, cb.dataset.projectsTeam, cb.checked); this.onFilterChange(); return }
      if ('membersAll' in cb.dataset) { this.clearSet(this.selectedMemberTeams, '[data-members-team]'); this.onFilterChange(); return }
      if ('membersTeam' in cb.dataset) { this.toggleInSet(this.selectedMemberTeams, cb.dataset.membersTeam, cb.checked); this.onFilterChange(); return }
      if ('statusValue' in cb.dataset) { this.reviewedFilter = cb.dataset.statusValue; this.onFilterChange(); return }
    })

    this._closeDropdown = (e) => {
      if (!e.target.closest('[data-repo-dropdown]') && !e.target.closest('[data-filter-dropdown]'))
        this.closeAllDropdowns()
    }
    document.addEventListener('click', this._closeDropdown)

    this.buildDynamicDropdowns()
    this.syncStaticCheckboxes()
    this.syncButtonStates()
    this.filterCommits()
  },

  destroyed() {
    document.removeEventListener('click', this._closeDropdown)
  },

  updated() {
    this.buildDynamicDropdowns()
    this.syncStaticCheckboxes()
    this.syncButtonStates()
    this.filterCommits()
  },

  // ── Helpers ────────────────────────────────────────────────────────────────

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

  clearSet(set, itemSelector) {
    set.clear()
    this.el.querySelectorAll(itemSelector).forEach(cb => { cb.checked = false })
    // re-check the matching "All" checkbox
    const allSel = itemSelector.replace('-team]', '-all]')
    this.el.querySelectorAll(allSel).forEach(cb => { cb.checked = true })
  },

  toggleInSet(set, value, checked) {
    checked ? set.add(value) : set.delete(value)
  },

  onFilterChange() {
    this.savePreferences()
    this.syncStaticCheckboxes()
    this.syncButtonStates()
    this.filterCommits()
  },

  // ── Persistence ────────────────────────────────────────────────────────────

  loadPreferences() {
    try {
      const s = JSON.parse(localStorage.getItem(this.storageKey) || '{}')
      this.selectedRepos = new Set(s.repos || [])
      this.selectedAuthors = new Set(s.authors || [])
      this.selectedProjectTeams = new Set(s.projectTeams || [])
      this.selectedMemberTeams = new Set(s.memberTeams || [])
      this.searchQuery = s.search || ''
      this.reviewedFilter = s.reviewedFilter || 'all'
    } catch (_) {
      this.selectedRepos = new Set()
      this.selectedAuthors = new Set()
      this.selectedProjectTeams = new Set()
      this.selectedMemberTeams = new Set()
      this.searchQuery = ''
      this.reviewedFilter = 'all'
    }
  },

  savePreferences() {
    localStorage.setItem(this.storageKey, JSON.stringify({
      repos: [...this.selectedRepos],
      authors: [...this.selectedAuthors],
      projectTeams: [...this.selectedProjectTeams],
      memberTeams: [...this.selectedMemberTeams],
      search: this.searchQuery,
      reviewedFilter: this.reviewedFilter,
    }))
  },

  // ── Dynamic dropdowns (built from DOM data) ────────────────────────────────

  buildDynamicDropdowns() {
    this.buildDynamicDropdown(
      '[data-author-checkboxes]',
      () => [...new Set(Array.from(this.el.querySelectorAll('[data-commit-item]')).flatMap(el => (el.dataset.authors || '').split(' ').filter(Boolean)))].sort(),
      this.selectedAuthors,
      (author, checked) => { this.toggleInSet(this.selectedAuthors, author, checked); this.onFilterChange() },
      () => { this.selectedAuthors.clear(); this.onFilterChange() },
      () => this.updateLabel('[data-author-label]', this.selectedAuthors, 'By')
    )

    this.buildDynamicDropdown(
      '[data-repo-checkboxes]',
      () => [...new Set(Array.from(this.el.querySelectorAll('[data-commit-item]')).map(el => el.dataset.repo).filter(Boolean))].sort(),
      this.selectedRepos,
      (repo, checked) => { this.toggleInSet(this.selectedRepos, repo, checked); this.savePreferences(); this.updateLabel('[data-repo-dropdown-label]', this.selectedRepos, 'Repo'); this.syncButtonStates(); this.filterCommits() },
      () => { this.selectedRepos.clear(); this.savePreferences(); this.updateLabel('[data-repo-dropdown-label]', this.selectedRepos, 'Repo'); this.syncButtonStates(); this.filterCommits() },
      () => this.updateLabel('[data-repo-dropdown-label]', this.selectedRepos, 'Repo')
    )
  },

  buildDynamicDropdown(containerSel, getValues, set, onChange, onClear, updateLabel) {
    const container = this.el.querySelector(containerSel)
    if (!container) return

    const values = getValues()
    set.forEach(v => { if (!values.includes(v)) set.delete(v) })

    container.innerHTML = ''
    container.appendChild(this.makeCheckboxLabel('All', null, set.size === 0, (_, checked) => { if (checked) onClear() }))
    values.forEach(v => container.appendChild(this.makeCheckboxLabel(v, v, set.has(v), onChange)))
    updateLabel()
  },

  makeCheckboxLabel(text, value, checked, onChange) {
    const label = document.createElement('label')
    label.className = 'flex items-center gap-2 px-3 py-0.5 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer whitespace-nowrap'
    const cb = document.createElement('input')
    cb.type = 'checkbox'
    cb.checked = checked
    cb.addEventListener('change', () => {
      if (value === null) {
        // "All" checkbox: uncheck all siblings, keep self checked
        label.closest('div').querySelectorAll('input').forEach(c => { c.checked = false })
        cb.checked = true
      }
      onChange(value, cb.checked)
      // Sync the All checkbox for this container
      const allCb = label.closest('div').querySelector('input:first-child')
      if (value !== null && allCb) allCb.checked = false
    })
    const span = document.createElement('span')
    span.textContent = text
    span.className = 'text-xs'
    label.appendChild(cb); label.appendChild(span)
    return label
  },

  // ── Static checkboxes (Projects/Members — pre-rendered in HTML) ───────────

  syncStaticCheckboxes() {
    this.el.querySelectorAll('[data-projects-all]').forEach(cb => { cb.checked = this.selectedProjectTeams.size === 0 })
    this.el.querySelectorAll('[data-projects-team]').forEach(cb => { cb.checked = this.selectedProjectTeams.has(cb.dataset.projectsTeam) })
    this.el.querySelectorAll('[data-members-all]').forEach(cb => { cb.checked = this.selectedMemberTeams.size === 0 })
    this.el.querySelectorAll('[data-members-team]').forEach(cb => { cb.checked = this.selectedMemberTeams.has(cb.dataset.membersTeam) })
    this.el.querySelectorAll('[data-status-value]').forEach(radio => { radio.checked = radio.dataset.statusValue === this.reviewedFilter })
    this.updateLabel('[data-projects-label]', this.selectedProjectTeams, 'Projects')
    this.updateLabel('[data-members-label]', this.selectedMemberTeams, 'Members')
    const statusLabels = { 'all': 'Status', 'unreviewed': 'Unreviewed', 'reviewed': 'Reviewed' }
    const statusLabelEl = this.el.querySelector('[data-status-label]')
    if (statusLabelEl) statusLabelEl.textContent = statusLabels[this.reviewedFilter] || 'Status'
  },

  // ── Labels & button state ─────────────────────────────────────────────────

  updateLabel(sel, set, defaultText) {
    const el = this.el.querySelector(sel)
    if (!el) return
    const count = set.size
    el.textContent = count === 0 ? defaultText : count === 1 ? [...set][0] : `${count} selected`
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

  // ── Filtering ─────────────────────────────────────────────────────────────

  filterCommits() {
    const query = this.searchQuery || ''

    this.el.querySelectorAll('[data-commit-wrapper]').forEach(wrapper => {
      const item = wrapper.querySelector('[data-commit-item]')
      if (!item) return

      const authors = (item.dataset.authors || '').split(' ').filter(Boolean)
      const projectTeams = (item.dataset.projectTeams || '').split(' ').filter(Boolean)
      const memberTeams = (item.dataset.memberTeams || '').split(' ').filter(Boolean)

      const ok =
        (!query ||
          (item.dataset.message || '').toLowerCase().includes(query) ||
          (item.dataset.sha || '').toLowerCase().includes(query) ||
          (item.dataset.repo || '').toLowerCase().includes(query) ||
          (item.dataset.authors || '').toLowerCase().includes(query)) &&
        (this.selectedRepos.size === 0 || this.selectedRepos.has(item.dataset.repo)) &&
        (this.selectedAuthors.size === 0 || authors.some(a => this.selectedAuthors.has(a))) &&
        (this.selectedProjectTeams.size === 0 || projectTeams.some(t => this.selectedProjectTeams.has(t))) &&
        (this.selectedMemberTeams.size === 0 || memberTeams.some(t => this.selectedMemberTeams.has(t))) &&
        (this.reviewedFilter === 'all' ||
          (this.reviewedFilter === 'reviewed' && item.dataset.reviewed === 'true') ||
          (this.reviewedFilter === 'unreviewed' && item.dataset.reviewed === 'false'))

      wrapper.classList.toggle('hidden', !ok)
    })
  },
}

Hooks.CommentSearch = {
  storageKey: 'remit:comment_filters',

  mounted() {
    this.isLoggedIn = !!this.el.dataset.username
    this.loadPreferences()

    const searchInput = this.el.querySelector('[data-comment-search]')
    if (searchInput) {
      if (this.searchQuery) searchInput.value = this.searchQuery
      searchInput.addEventListener('input', (e) => {
        this.searchQuery = e.target.value.toLowerCase()
        this.savePreferences()
        this.filterComments()
      })
    }

    this.el.addEventListener('click', (e) => {
      const filterToggle = e.target.closest('[data-filter-dropdown-toggle]')
      if (filterToggle) {
        e.stopPropagation()
        const dropdown = filterToggle.closest('[data-filter-dropdown]')
        const panel = dropdown?.querySelector('[data-filter-dropdown-panel]')
        const chevron = filterToggle.querySelector('[data-filter-chevron]')
        const isOpen = !panel?.classList.contains('hidden')
        this.closeAllDropdowns()
        if (!isOpen) { panel?.classList.remove('hidden'); chevron?.classList.add('rotate-180') }
        return
      }
    })

    this.el.addEventListener('change', (e) => {
      const input = e.target
      if (!input.matches('input[type="radio"]')) return
      if ('commentStatusValue' in input.dataset) { this.resolvedFilter = input.dataset.commentStatusValue; this.onFilterChange(); return }
      if ('commentRoleValue' in input.dataset) { this.roleFilter = input.dataset.commentRoleValue; this.onFilterChange(); return }
    })

    this._closeDropdown = (e) => {
      if (!e.target.closest('[data-filter-dropdown]')) this.closeAllDropdowns()
    }
    document.addEventListener('click', this._closeDropdown)

    this.syncStaticInputs()
    this.syncButtonStates()
    this.filterComments()
  },

  destroyed() {
    document.removeEventListener('click', this._closeDropdown)
  },

  updated() {
    this.syncStaticInputs()
    this.syncButtonStates()
    this.filterComments()
  },

  closeAllDropdowns() {
    this.el.querySelectorAll('[data-filter-dropdown-panel]').forEach(p => p.classList.add('hidden'))
    this.el.querySelectorAll('[data-filter-dropdown-toggle] [data-filter-chevron]').forEach(c => c.classList.remove('rotate-180'))
  },

  onFilterChange() {
    this.savePreferences()
    this.syncStaticInputs()
    this.syncButtonStates()
    this.filterComments()
  },

  loadPreferences() {
    try {
      const s = JSON.parse(localStorage.getItem(this.storageKey) || '{}')
      this.resolvedFilter = s.resolvedFilter || 'unresolved'
      this.roleFilter = s.roleFilter || (this.isLoggedIn ? 'for_me' : 'all')
      this.searchQuery = s.search || ''
    } catch (_) {
      this.resolvedFilter = 'unresolved'
      this.roleFilter = this.isLoggedIn ? 'for_me' : 'all'
      this.searchQuery = ''
    }
  },

  savePreferences() {
    localStorage.setItem(this.storageKey, JSON.stringify({
      resolvedFilter: this.resolvedFilter,
      roleFilter: this.roleFilter,
      search: this.searchQuery,
    }))
  },

  syncStaticInputs() {
    this.el.querySelectorAll('[data-comment-status-value]').forEach(r => { r.checked = r.dataset.commentStatusValue === this.resolvedFilter })
    this.el.querySelectorAll('[data-comment-role-value]').forEach(r => { r.checked = r.dataset.commentRoleValue === this.roleFilter })

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

  filterComments() {
    const query = this.searchQuery || ''

    this.el.querySelectorAll('[data-comment-wrapper]').forEach(wrapper => {
      const item = wrapper.querySelector('[data-comment-item]')
      if (!item) return

      const ok =
        (!query ||
          (item.dataset.body || '').toLowerCase().includes(query)) &&
        (this.resolvedFilter === 'all' ||
          (this.resolvedFilter === 'resolved' && item.dataset.resolved === 'true') ||
          (this.resolvedFilter === 'unresolved' && item.dataset.resolved === 'false')) &&
        (this.roleFilter === 'all' ||
          (this.roleFilter === 'for_me' && item.dataset.forMe === 'true') ||
          (this.roleFilter === 'by_me' && item.dataset.byMe === 'true'))

      wrapper.classList.toggle('hidden', !ok)
    })
  },
}

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

Hooks.BuildCommitRepos = {
  mounted() {
    this.handleEvent('build-commit-repos-updated', ({ repos }) => {
      const formData = new FormData()
      repos.forEach(r => formData.append('repos[]', r))
      fetch('/api/build_commit_repos', { method: 'post', body: formData })
    })
  }
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
