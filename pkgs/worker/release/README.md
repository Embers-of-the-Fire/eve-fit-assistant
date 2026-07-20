# release — Cloudflare Worker

Exposes the latest release artifact for each EFA update channel.

## API

### `GET /releases/artifact`

Returns the current release for a given channel.

**Query parameters**

| Param | Type | Description |
|-------|------|-------------|
| `channel` | `string` | Channel name (`testing`, `stable`, etc.). Defaults to the registry's `defaultChannel`. |

**Response `200 OK`**

```json
{
  "ok": true,
  "release": {
    "id": "efav2-…",
    "version": "0.1.0",
    "channel": "testing",
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
}
```

**Error response `200 OK`** (with `ok: false`)

```json
{
  "ok": false,
  "error": "channel 'nonexistent' not found"
}
```

The worker does not use HTTP status codes for errors; always check the `ok` field.

## Architecture

1. Reads the **channel registry** from `efa/v2/channels/heads/channels.json` in the bound R2 bucket.
2. Resolves the channel head to a **generation hash** via `efa/v2/channels/heads/{channel}/metadata.json`.
3. Fetches the **`GenerationPointer`** protobuf at `efa/v2/channels/refs/{hash}/releases.pb2` to get the snapshot hash.
4. Fetches the **`ReleaseIndex`** protobuf at `efa/v2/assets/releases/{snapshot}/releases.pb2`.
5. Builds signed download URLs pointing to `{origin}/efa/v2/assets/blobs/{prefix}/{hash}/{blob}`.

## Local dev

```bash
nix-shell shell.nix --run "wrangler dev"
```

Requires the R2 bucket and `BLOB_ORIGIN` variable to be configured in `wrangler.toml`.

## Build

```bash
nix-shell shell.nix --run "worker-build --release --no-opt"
```
