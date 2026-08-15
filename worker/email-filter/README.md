# email-filter

[Cloudflare Email Routing Worker][cf-email-worker] for **[efa-tech.dev][site]**
that filters incoming emails by subject.

## Behaviour

- **Reject** emails whose subject does **not** start with `[EFA/Security]`.
- **Forward** matching emails to the address configured in the `FORWARD_TO`
  secret.

## Setup

The recipient address is stored as a Cloudflare Worker secret:

```bash
wrangler secret put FORWARD_TO
```

Local development uses `wrangler dev` with the `send_email` binding defined in
[`wrangler.toml`](wrangler.toml) — forwarded emails are written to temporary
`.eml` files on disk.

For local testing, copy `.dev.vars.example` to `.dev.vars`:

```bash
cp .dev.vars.example .dev.vars
```

## Develop

```bash
pnpm --filter email-filter dev
```

or from repo root:

```bash
pnpm dev:email-filter
```

## Deploy

```bash
pnpm --filter email-filter deploy
```

Don't forget to set `FORWARD_TO` in production first:

```bash
pnpm --filter email-filter exec wrangler secret put FORWARD_TO
```

## Test locally

Wrangler exposes a `/cdn-cgi/handler/email` endpoint that accepts `POST`ed raw
email messages. Use `curl` to test:

```bash
curl --request POST 'http://localhost:8788/cdn-cgi/handler/email' \
  --url-query 'from=sender@example.com' \
  --url-query 'to=recipient@efa-tech.dev' \
  --header 'Content-Type: application/json' \
  --data-raw 'Subject: [EFA/Security] Test alert

This mail should be forwarded.'
```

## Route setup

In the [Cloudflare Dashboard][cf-dash], go to **Email** → **Email Routing** →
**Routing Rules**. Add a catch-all rule that routes all incoming email to this
Worker. This cannot be configured in `wrangler.toml` — it must be set through
the Dashboard.

[site]: https://efa-tech.dev
[cf-email-worker]: https://developers.cloudflare.com/email-routing/email-workers/
[cf-dash]: https://dash.cloudflare.com
