// lint-staged configuration
// Run linters on staged files
// See: https://github.com/lint-staged/lint-staged

export default {
  // Ruby files
  '*.{rb,rake}': ['bundle exec rubocop -f github --autocorrect-all'],

  // ERB templates
  '*.erb': ['bundle exec erb_lint --autocorrect'],

  // JavaScript/TypeScript files
  '*.{js,ts,mjs,cjs}': ['eslint --fix', 'prettier --write'],

  // JSON, YAML, Markdown
  '*.{json,yml,yaml,md}': ['prettier --write'],
};
