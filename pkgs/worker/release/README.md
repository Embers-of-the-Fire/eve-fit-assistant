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
      },
      "linux": {
        "appimage": {
          "identifier": "dev.efa-tech…",
          "content_hash": "sha256…",
          "size": 12345678,
          "download_url": "https://api.efa-tech.dev/releases/download/testing/appimage/sha256…"
        },
        "native":   { … }
      },
      "windows": {
        "native": {
          "identifier": "dev.efa-tech…",
          "content_hash": "sha256…",
          "size": 12345678,
          "download_url": "https://api.efa-tech.dev/releases/download/testing/native/sha256…"
        },
        "installer": { … }
      }
    }
  },
  "channels": ["testing"]
}
```

A channel whose head generation has an empty release pointer (no app release
staged yet) is simply omitted from `artifacts`. If a channel's release chain
is corrupt (e.g. a dangling non-empty snapshot pointer), that channel is
omitted from `artifacts` and an `errors` object is included instead of
failing the whole route:

```json
{
  "ok": true,
  "artifacts": { … },
  "channels": ["testing", "stable"],
  "errors": {
    "stable": "release index not found for snapshot: …"
  }
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

Streams the artifact blob for the given channel and variant directly from R2.
Android variants are `general`, `armv7`, `arm64`, `x64` (served as
`application/vnd.android.package-archive`); Linux variants are `appimage`
(served as `application/vnd.appimage`) and `native` (served as
`application/zip`); Windows variants are `installer` (served as
`application/x-msi`) and `native` (served as `application/zip`). Variant
names are not unique across platforms (both Linux and Windows ship a
`native` zip), so the variant is resolved against every platform and
disambiguated by the `{hash}` path segment, which must equal the variant's
current `content_hash`, making the URL content-addressed. The
response carries a proper download name via `Content-Disposition`, e.g.:

```text
Content-Type: application/vnd.android.package-archive
Content-Disposition: attachment; filename="eve-fit-assistant-0.1.0-arm64.apk"
Content-Length: 12345678
Cache-Control: public, max-age=31536000, immutable
```

or, for Linux:

```text
Content-Type: application/vnd.appimage
Content-Disposition: attachment; filename="eve-fit-assistant-0.1.0-linux.AppImage"
Cache-Control: public, max-age=31536000, immutable
```

or, for Windows:

```text
Content-Type: application/x-msi
Content-Disposition: attachment; filename="eve-fit-assistant-0.1.0-windows-setup.msi"
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
