# CI Configuration

Scope: tracked CI configuration under `ci/config/`.

- `ci/config/efa.dev.toml` is the tracked, non-secret developer config used by CI; secret
  fields use `.invalid` placeholders.
- `.github/actions/init-dev-env` copies it to `./efa.dev.toml` after checkout.
- Jobs inject real secrets through `--dev-env` overrides on top of the tracked config.
- `ci/config/wrangler.{prod,nightly}.toml` are copied to `./wrangler.toml` by the web deploy
  action because wrangler requires a config file.
- Do not commit credentials, tokens, private endpoints, or real secret values here.

See @docs/agents/ci-release for environment and secret ownership.
