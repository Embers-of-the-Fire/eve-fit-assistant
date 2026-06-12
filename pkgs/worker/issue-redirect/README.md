# issue-redirect

Cloudflare Worker that receives form submissions and creates GitHub issues via the GitHub App API.

Target repo: `Embers-of-the-Fire/eve-fit-assistant`

## API

### `POST /api/issue/bug-report`

Create a bug report issue.

```json
{
    "title": "App crashes on startup",
    "language": "en",
    "summary": "App crashes on startup",
    "steps": "1. Open app\n2. Observe crash",
    "expected": "App opens normally",
    "actual": "App shows white screen and exits",
    "platform": "Android",
    "version": "0.1.0",
    "logs": "Error: null pointer exception",
    "contact": "user@example.com",
    "metadata": {
        "os_version": "Android 14",
        "device": "Pixel 8"
    }
}
```

### `POST /api/issue/feature-request`

Create a feature request issue.

```json
{
    "title": "Add sort-by-DPS toggle",
    "language": "en",
    "problem": "Cannot sort fits by DPS",
    "proposal": "Add a sort-by-DPS toggle",
    "impact": "Helps quickly find the best fit",
    "alternatives": "Could also sort by EHP",
    "extra": "See mockup at ..."
}
```

### Response

#### Success (201)

```json
{
    "issue_url": "https://github.com/Embers-of-the-Fire/eve-fit-assistant/issues/42",
    "issue_number": 42
}
```

#### Validation Error (400)

```json
{
    "error": "Validation failed",
    "details": [
        { "path": "summary", "message": "summary is required" }
    ]
}
```

#### Config Error (500)

```json
{
    "error": "Server misconfigured",
    "details": "Missing required environment variables: GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY"
}
```

## Setup

### 1. Register a GitHub App

1. Go to your user or organization **Settings > Developer settings > GitHub Apps > New GitHub App**.

2. Fill in the form:
   - **GitHub App name:** `issue-redirect` (or any name)
   - **Homepage URL:** your project URL
   - **Webhook:** uncheck "Active" (not needed)

3. Under **Repository permissions**, set:
   - **Issues:** Read & Write

4. Under **Where can this GitHub App be installed?**, choose **Only on this account**.

5. Click **Create GitHub App**.

6. After creation, note the **App ID** at the top of the page — this is `GITHUB_APP_ID`.

7. Scroll down to **Private keys** and click **Generate a private key**. A `.pem` file will download. Copy its full contents (including `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----`) — this is `GITHUB_APP_PRIVATE_KEY`.

8. Go to the **Install App** tab in the sidebar, click **Install** next to your account, and select the repository `Embers-of-the-Fire/eve-fit-assistant`. Click **Install**.

9. After installation, you will be redirected to the installation page. The URL looks like:
   `https://github.com/settings/installations/12345678`
   
   The number at the end is your `GITHUB_APP_INSTALLATION_ID`.

### 2. Configure Secrets

**Development** — copy `.dev.vars.example` to `.dev.vars` and fill in:

```bash
cp .dev.vars.example .dev.vars
```

**Production** — use `wrangler secret put`:

```bash
wrangler secret put GITHUB_APP_ID
wrangler secret put GITHUB_APP_PRIVATE_KEY
wrangler secret put GITHUB_APP_INSTALLATION_ID
```

### 3. Develop

```bash
pnpm --filter issue-redirect dev
```

or from repo root:

```bash
pnpm dev:redirect
```

### 4. Deploy

```bash
pnpm --filter issue-redirect deploy
```
