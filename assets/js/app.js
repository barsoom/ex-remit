// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
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
// - Makes it so that repeat clicks of the same link (or buttons inside that link) don't re-open it every time.
// - Makes it so clicks in dev don't actually open links, unless inside Fluid.app, for convenience.
Hooks.FixLink = {
  mounted() {
    // Outside Fluid.app, in a regular browser, new tabs are less disruptive than opening in the same window.
    // In Fluid.app, we can't add a "target" attribute or they'd open in a new tab instead of in the main window next to the Remit panel.
    // We use a named target rather than "_blank" so it's reused. This means you put the opened window side-by-side with Remit and have a halfway decent Fluid-like experience.
    if (!window.fluid) this.el.setAttribute("target", "github_window")

    this.el.addEventListener("click", (e) => {
      // If this is the last link we clicked, don't re-visit it. We'd reload the page (in Fluid) or open yet another tab (in a regular browser).
      if (window.remitLastClickedLink === this.el) {
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
      document.getElementById(id).scrollIntoView()
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
  },
 }

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits.
let progressTimeout = null
window.addEventListener("phx:page-loading-start", () => { clearTimeout(progressTimeout); progressTimeout = setTimeout(NProgress.start, 100) })
window.addEventListener("phx:page-loading-stop", () => { clearTimeout(progressTimeout); NProgress.done() })

// Don't show a spinner in addition to the progress bar.
NProgress.configure({ showSpinner: false })

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket


/* CONNECTION DETECTION SOCKET */

// We use a socket with a frequent "heartbeat" to detect two situations:
//
// 1. You've lost your connection for a while (computer sleep, network blip…). We reload to ensure you didn't miss any updates. Until you reconnect and are reloaded, the .consocket-closed CSS indicates something is wrong.
//
// 2. A new revision of the app is deployed, so the socket is killed on the server-side and then you're reconnected. We reload to ensure you've got the latest app.
//
// To achieve this, we set a frequent heartbeat both here in the client, and on the server-side via endpoint.ex. See: https://elixirforum.com/t/can-phoenix-channel-detect-client-offline-immediately-like-wifi-disconnected/25104/18
//
// If we set the heartbeat/timeout values too low, any bit of latency will set it off, so we try to strike a balance.

let authKey = document.querySelector("meta[name='auth_key']").getAttribute("content")
let conSocket = new Socket("/consocket", {
  params: {auth_key: authKey},
  heartbeatIntervalMs: 5000,  // Should be shorter than endpoint.ex socket timeout.
})

conSocket.onClose(() => document.body.classList.add("consocket-closed"))

let hasConnectedBefore = false
conSocket.onOpen(() => {
  if (hasConnectedBefore) {
    console.log("It's a re-connect, fellows! Reloading the browser.")
    location.reload()
  } else {
    hasConnectedBefore = true
  }
})

conSocket.connect()
