# CI Configuration

Scope: tracked CI configuration under `ci/config/`.

- Do not commit credentials, tokens, private endpoints, or real secret values here.
- `ci/config/efa.dev.toml` is the tracked, non-secret developer config used by CI; secret
  fields use `.invalid` placeholders. `.github/actions/init-dev-env` copies it to
  `./efa.dev.toml` after checkout; jobs inject real secrets through `--dev-env` overrides.
- `ci/config/wrangler.{prod,nightly}.toml` are copied to `./wrangler.toml` by the web deploy
  action because wrangler requires a config file.

## Docs

- Environment and secret ownership: [docs/dev/ci-release.md](../docs/dev/ci-release.md)
