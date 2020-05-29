module.exports = {
  purge: [
    "../**/*.html.eex",
    "../**/*.html.leex",
    "../**/views/**/*.ex",
    "../**/live/**/*.ex",
    "./js/**/*.js",
  ],
  theme: {

    // This implements our own, more limited color palette within the broader default one. If we just want "some lightish yellow", we can just pick a default colour by feel, nevermind that we may use `-200` in one place and `-300` in another. If we do something where we care more about sticking to a limited palette, we use these.
    //
    // Longer term we may end up replacing all the default colours, but until then it's useful to have them to fall back on.
    textColor: theme => ({
      ...theme("colors"),
      "gray-mid": theme("colors.gray.600"),
      "yellow-mid": theme("colors.yellow.600"),
    }),
    borderColor: theme => ({
      ...theme("colors"),
      "gray-mid": theme("colors.gray.500"),
      "gray-light": theme("colors.gray.300"),
    }),
    backgroundColor: theme => ({
      ...theme("colors"),
      "green-light": theme("colors.green.100"),
    }),

    extend: {
    },
  },
  variants: {},
  plugins: [],
}
