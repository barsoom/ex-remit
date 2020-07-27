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


/* CONNECTION DETECTION AND NEW DEPLOY DETECTION
 *
 * We set up our own socket and channel to handle two scenarios:
 *
 * 1. You've lost your connection for a while (computer sleep, network blip…). We detect it via pings from the server, and reload the page to ensure you didn't miss any updates. See: https://elixirforum.com/t/can-phoenix-channel-detect-client-offline-immediately-like-wifi-disconnected/25104/18
 *
 * 2. A new revision of the app is deployed, so we should reload the page to ensure you use the new revision. Heroku will close the socket briefly during deploy, causing a reconnection. We detect that reconnect, and reload the page.
 *
 * We can't rely on #1 alone, since the restart may be quicker than our ping-detection threshold. We also can't rely solely on #2, because it is only likely to reconnect quickly when the socket is shut down cleanly on the server and tells the client. Otherwise it can take a minute or so for the client to realise the socket is dead.
 *
 * We try to strike a balance between not triggering at every brief connection blip, and detecting longer blips quickly, but there are no guarantees that we can't miss ill-timed broadcasts during a below-the-threshold blip. That's acceptable for this app.
 */

const OFFLINE_IF_UNPUNG_FOR_SECONDS = 5

let authKey = document.querySelector("meta[name='auth_key']").getAttribute("content")
let socket = new Socket("/socket", {params: {auth_key: authKey}})
socket.connect()

let pingChannel = socket.channel("ping", {})

let hasJoinedBefore = false
pingChannel.join().receive("ok", () => {
  if (hasJoinedBefore) {
    location.reload()
  } else {
    hasJoinedBefore = true
  }
})

let isOffline = false
let setAsOfflineTimer = null
pingChannel.on("ping", () => {
  if (isOffline) { location.reload() }

  clearTimeout(setAsOfflineTimer)

  setAsOfflineTimer = setTimeout(() => {
    isOffline = true
    document.body.classList.add("ping-offline")
  }, OFFLINE_IF_UNPUNG_FOR_SECONDS * 1000)
})
