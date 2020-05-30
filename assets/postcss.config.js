module.exports = {
  plugins: [
    require("postcss-import"),
    require("tailwindcss"),

    /* Sass-like nesting: https://github.com/postcss/postcss-nested */
    require("postcss-nested"),

    require("autoprefixer"),
  ],
}
