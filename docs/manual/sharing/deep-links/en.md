---
title: In-App Links
summary: How links inside app content navigate to pages or the browser.
---

# In-App Links

Links found in app content — manual pages, announcements, and similar text — are handled consistently wherever they appear.

**Internal links** use the `efa://` scheme. The part after the scheme is an in-app page path, so `efa://manual/sharing` opens this manual section. Tapping one pushes that page onto the navigation stack, just like navigating there yourself.

**External links** — `https://`, `mailto:`, and other schemes — open in your device's external browser or the matching app.

Content authors can also write links relative to the current page (including `..` to go up a level); they resolve to the same internal pages.

If an internal link points to a page that does not exist, the tap is ignored and the miss is recorded in the app log — nothing breaks.

Note: `efa://` links navigate *within* the app. They are not web URLs. For opening fits from links shared outside the app, see fit links below.

# Fit Links

The export dialog's **Copy link** action produces a share URL like:

```text
https://share.platform.efa-tech.dev/fit/raw?payload=EFA2:...
```

The payload carries the complete fit in the app-native format (the same content as the EFA native text export), encoded directly in the URL — nothing is uploaded to a server. Fits that are too large to fit in a URL cannot be shared this way; use the text export instead.

Opening a fit link shows a small chooser page where the recipient picks how to open it:

- **Open in app** — launches the installed app and imports the fit (as a copy; existing fits are never modified). If no app responds, the page offers a download link.
- **Open in web app** — imports the fit into the web app at `app.efa-tech.dev`.
- **Open in nightly** — the same against the preview build.

Each option can be remembered; the next link then redirects automatically, with a cancel control and a reset option.

Platform support:

- **Android** — verified App Links for all link hosts, plus the `efa://` scheme. Opening a link goes straight to the app once verified.
- **Windows** — installing the MSI registers the `efa://` protocol.
- **Linux** — best-effort: the AppImage desktop entry declares `x-scheme-handler/efa`, which applies only if your AppImage launcher integration (e.g. appimaged or Gear Lever) installs desktop entries.
- **Web** — opening a fit link on either web app imports the fit and removes the payload from the address bar.

A link that is damaged or not a fit link shows an error in the app, or a "link not found" page on the share host — nothing is imported in either case.
