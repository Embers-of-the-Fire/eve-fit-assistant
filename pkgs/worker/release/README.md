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
          "download_url": "https://…/efa/v2/assets/blobs/…"
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

The worker does not use HTTP status codes for errors; always check the `ok` field.

## Architecture

1. Reads the **channel registry** from `efa/v2/channels/heads/channels.json` in the bound R2 bucket.
2. Resolves the channel head to a **generation hash** via `efa/v2/channels/heads/{channel}/metadata.json`.
3. Fetches the **`GenerationPointer`** protobuf at `efa/v2/channels/refs/{hash}/releases.pb2` to get the snapshot hash.
4. Fetches the **`ReleaseIndex`** protobuf at `efa/v2/assets/releases/{snapshot}/releases.pb2`.
5. Builds signed download URLs pointing to `{origin}/efa/v2/assets/blobs/{prefix}/{hash}/{blob}`.
