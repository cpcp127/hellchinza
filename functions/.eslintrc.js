module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json"],
    tsconfigRootDir: __dirname,
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*",
    "/generated/**/*",
    ".eslintrc.js", // ✅ 추가
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
      "quotes": ["error", "double"],
      "import/no-unresolved": 0,
      "indent": ["error", 2],

      // ✅ 추가
      "require-jsdoc": 0,
      "max-len": 0,
      "no-constant-condition": 0,
      "no-empty": 0,
      "@typescript-eslint/no-unused-vars": 0,
    },
};