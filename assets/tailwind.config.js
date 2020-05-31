const { colors } = require("tailwindcss/defaultTheme")

module.exports = {
  purge: [
    "../**/*.html.eex",
    "../**/*.html.leex",
    "../**/views/**/*.ex",
    "../**/live/**/*.ex",
    "./js/**/*.js",
  ],
  theme: {
    extend: {

      // This implements our own, more limited color palette within the broader default one. If we just want "some lightish yellow", we can just pick a default colour by feel, nevermind that we may use `-200` in one place and `-300` in another. If we do something where we care more about sticking to a limited palette, we use these.
      //
      // Longer term we may end up replacing all the default colours, but until then it's useful to have them to fall back on.
      colors: {
        "gray-light": colors.gray["300"],
        "gray-mid": colors.gray["500"],
        "gray-dark": colors.gray["600"],
        "almost-black": colors.gray["900"],

        "yellow-mid": colors.yellow["600"],

        "green-light": colors.green["100"],
        "green-mid": colors.green["500"],
        "green-dark": colors.green["700"],
      },

    },
  },
  variants: {},
  plugins: [],
}
