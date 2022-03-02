// We need to import the CSS so that webpack will load it. The MiniCssExtractPlugin is used to separate it out into its own CSS file.
import "../css/app.css"

// webpack automatically bundles all modules in your entry points. Those entry points can be configured in "webpack.config.js".
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "phoenix_html"
import {Socket} from "phoenix"
import NProgress from "nprogress"
import {LiveSocket} from "phoenix_live_view"


/* LIVE SOCKET */

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

// - Fixes an issue where clicking a link with a phx-click on it did not cause the link default (navigation) to trigger.
// - Adds a target attribute to links when outside Fluid.app, so Remit stays open.
// - Makes it so that clicking buttons inside a link doesn't re-open it every time. (But clicking outside buttons opens it every time, so you can always navigate back to the commit/comment.)
// - Makes it so clicks in dev don't actually open links, unless inside Fluid.app, for convenience.
Hooks.FixLink = {
  mounted() {
    // Outside Fluid.app, in a regular browser, new tabs are less disruptive than opening in the same window.
    // In Fluid.app, we can't add a "target" attribute or they'd open in a new tab instead of in the main window next to the Remit panel.
    // We use a named target rather than "_blank" so it's reused. This means you put the opened window side-by-side with Remit and have a halfway decent Fluid-like experience.
    if (!window.fluid) this.el.setAttribute("target", "github_window")

    this.el.addEventListener("click", (e) => {
      const didClickButton = !!e.target.closest("button")

      // If this is the last link we clicked, don't re-visit it on a button click. We'd reload the page (in Fluid) or open yet another tab (in a regular browser).
      if (window.remitLastClickedLink === this.el && didClickButton) {
        e.preventDefault()
        return
      }

      window.remitLastClickedLink = this.el

      // In dev outside Fluid.app, we typically care more about the Remit UI than opening links, so skip it.
      let isDev = (location.hostname === "localhost")
      if (isDev && !window.fluid) {
        console.log("Skipping link opening in dev when outside Fluid.app. Link: ", this.el.href)
        e.preventDefault()
      }
    })
  }
}

Hooks.ScrollToTarget = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      let id = this.el.href.split("#")[1]
      e.preventDefault()

      // `block: "center"` because the default `"start"` means it's likely to end up right under a sticky date header.
      document.getElementById(id).scrollIntoView({block: "center"})
    })
  }
}

Hooks.SetSession = {
  DEBOUNCE_MS: 200,

  mounted() {
    this.el.addEventListener("input", (e) => {
      clearTimeout(this.timeout)
      this.timeout = setTimeout(() => {
        this.pushEventTo(".phx-hook-subscribe-to-session", "set_session", [e.target.name, e.target.value])
        fetch(`/api/session?${e.target.name}=${encodeURIComponent(e.target.value)}`, { method: "post" })
      }, this.DEBOUNCE_MS)
    })
  }
 }

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits.
let progressTimeout = null
window.addEventListener("phx:page-loading-start", (info) => {
  clearTimeout(progressTimeout)
  progressTimeout = setTimeout(NProgress.start, 100)
  if (info?.detail?.kind === "error") {
    // wait to be sure is a disconnect and not a page reload
    setTimeout(function(){document.body.classList.add("ping-offline")}, 500)
  }
})

window.addEventListener("phx:page-loading-stop", (info) => {
  clearTimeout(progressTimeout)
  if (info.detail?.kind === "initial" && document.body.classList.contains("ping-offline")) {
    location.reload()
  }
  NProgress.done()
})

// Don't show a spinner in addition to the progress bar.
NProgress.configure({ showSpinner: false })

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket

let authKey = document.querySelector("meta[name='auth_key']").getAttribute("content")
let socket = new Socket("/socket", {params: {auth_key: authKey}, heartbeatIntervalMs: 15000})
socket.connect()
