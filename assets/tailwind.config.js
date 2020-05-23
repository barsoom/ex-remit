module.exports = {
  purge: [
    "../**/*.html.eex",
    "../**/*.html.leex",
    "../**/views/**/*.ex",
    "../**/live/**/*.ex",
    "./js/**/*.js",
  ],
  theme: {
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
