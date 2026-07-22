# release — Cloudflare Worker

Exposes the latest release artifact for each EFA update channel.

## API

### `GET /releases/artifacts`

Returns the current release artifact for every channel in the registry.

No query parameters — the worker reads all channels from `efa/v2/channels/heads/channels.json` in the bound R2 bucket.

**Response `200 OK`**

```json
{
  "ok": true,
  "artifacts": {
    "testing": {
      "id": "efav2-…",
      "version": "0.1.0",
      "android": {
        "general": {
          "identifier": "com.evefitassistant…",
          "content_hash": "sha256…",
          "size": 12345678,
          "download_url": "https://api.efa-tech.dev/releases/download/testing/general/sha256…"
        },
        "armv7":  { … },
        "arm64":  { … },
        "x64":    { … }
      }
    }
  },
  "channels": ["testing"]
}
```

**Error response `200 OK`** (with `ok: false`)

```json
{
  "ok": false,
  "artifacts": null,
  "channels": [],
  "error": "channel registry not found: …"
}
```

The artifacts endpoint does not use HTTP status codes for errors; always check the `ok` field.

### `GET /releases/download/{channel}/{variant}/{hash}`

Streams the APK blob for the given channel and variant (`general`, `armv7`,
`arm64`, `x64`) directly from R2. The `{hash}` path segment must equal the
variant's current `content_hash`, making the URL content-addressed. The
response carries a proper download name via `Content-Disposition`, e.g.:

```text
Content-Type: application/vnd.android.package-archive
Content-Disposition: attachment; filename="eve-fit-assistant-0.1.0-arm64.apk"
Content-Length: 12345678
Cache-Control: public, max-age=31536000, immutable
```

Returns `404` when the channel, variant, or blob does not exist, or when
`{hash}` does not match the channel's current release (a stale URL after a
channel update); hash-mismatch responses are sent with `Cache-Control:
no-cache`. Because the URL embeds the blob's content hash, successful
responses are safe to cache immutably — a channel update always produces a
new URL.

## Architecture

1. Reads the **channel registry** from `efa/v2/channels/heads/channels.json` in the bound R2 bucket.
2. Resolves the channel head to a **generation hash** via `efa/v2/channels/heads/{channel}/metadata.json`.
3. Fetches the **`GenerationPointer`** protobuf at `efa/v2/channels/refs/{hash}/releases.pb2` to get the snapshot hash.
4. Fetches the **`ReleaseIndex`** protobuf at `efa/v2/assets/releases/{snapshot}/releases.pb2`.
5. Exposes per-variant download URLs under `/releases/download/{channel}/{variant}/{hash}`, where `{hash}` is the variant's content hash, which stream the blob at `efa/v2/assets/blobs/{prefix}/{hash}/{blob}` with a `Content-Disposition` filename.
