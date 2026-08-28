---
title: Publishing Fits
summary: Publish a fit to the EFA Platform as a public post with an interactive snapshot and a discussion thread.
---

# Publishing Fits

Publishing uploads a fit to the EFA Platform (`platform.efa-tech.dev`) and creates a public **post** for it: a page anyone can open in a browser, showing an interactive fit snapshot with ship details, plus a discussion thread where signed-in users can post markdown comments. Posts are linked to the publishing account, which can delete its own posts from the post page; moderators can remove any post.

Publishing is the only feature that uploads fit data to a server — fits otherwise stay on your device.

## Requirements

Publishing requires a signed-in platform account with publish permission, which every account has by default. See [Account](efa://manual/pages/settings/account). The **Share** action only appears while you are signed in and permitted.

The platform must also have ingested the data snapshot your app currently uses; if it has not, publishing fails with an error — try again later.

## Sharing a Fit

On the [Fits tab](efa://manual/pages/home/fit-list), swipe an item right and tap **Share**. The share dialog shows the fit's name; tap **Share** to publish it.

The platform deduplicates identical fits: if the same fit has been published before, the existing post is reused instead of creating a new one. Either way, the dialog reports the outcome and opens the post page in your browser. If the page cannot be opened, use **Copy link** in the dialog to copy the post URL instead.

Failures — an expired session, missing publish permission, an unready data repository, a snapshot the platform has not ingested yet, a fit the platform rejects or cannot recognize, or a network error — are shown as messages in the dialog.
