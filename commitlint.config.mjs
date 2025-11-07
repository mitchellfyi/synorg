// Commitlint configuration
// Enforces Conventional Commits specification
// See: https://www.conventionalcommits.org/

export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Enforce lowercase type
    'type-case': [2, 'always', 'lower-case'],
    // Enforce lowercase scope
    'scope-case': [2, 'always', 'lower-case'],
    // Subject should not be empty
    'subject-empty': [2, 'never'],
    // Subject should not end with period
    'subject-full-stop': [2, 'never', '.'],
    // Type is required
    'type-empty': [2, 'never'],
    // Valid types
    'type-enum': [
      2,
      'always',
      [
        'build',    // Changes to build system or external dependencies
        'chore',    // Other changes that don't modify src or test files
        'ci',       // Changes to CI configuration files and scripts
        'docs',     // Documentation only changes
        'feat',     // A new feature
        'fix',      // A bug fix
        'perf',     // A code change that improves performance
        'refactor', // A code change that neither fixes a bug nor adds a feature
        'revert',   // Reverts a previous commit
        'style',    // Changes that do not affect the meaning of the code
        'test',     // Adding missing tests or correcting existing tests
      ],
    ],
  },
};
