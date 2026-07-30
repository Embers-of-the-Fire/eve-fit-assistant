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

Note: `efa://` links navigate *within* the app. They are not web URLs, and opening fits from links outside the app (OS-level deep links) is not currently supported.
