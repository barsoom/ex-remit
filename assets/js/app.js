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

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

// - Fixes an issue where clicking a link with a phx-click on it did not cause the link default (navigation) to trigger.
// - Adds target=_blank when outside Fluid.app.
// - Makes it so that repeat clicks of the same link (or buttons inside that link) don't re-open it every time.
// - Makes it so clicks in dev don't actually open links, unless inside Fluid.app, for convenience.
Hooks.FixLink = {
  mounted() {
    // Outside Fluid.app, in a regular browser, new tabs are less disruptive than opening in the same window.
    // In Fluid.app, we can't add target="_blank" or they'd open in a new tab instead of in the main window next to the Remit panel.
    if (!window.fluid) this.el.setAttribute("target", "_blank")

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
