# Loadout engineering defaults

- Make precise changes that address the requested outcome without unrelated
  refactoring.
- Preserve existing behaviour unless a change is explicitly requested.
- Reuse existing helpers and conventions before introducing abstractions.
- Keep types and error handling explicit; never hide failures behind fallback
  success.
- Run the smallest relevant lint, test and build commands before declaring
  work complete.
- Never print, commit or copy credentials, tokens, passwords, private keys or
  personal data.
- Use placeholders and environment variables whenever configuration requires
  a secret.
- Ask before destructive filesystem, Git, cloud or infrastructure operations.
