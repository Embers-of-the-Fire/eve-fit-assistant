---
title: Checkout History & Rollback
summary: Revert a checkout to an earlier data version when an update causes problems.
---

# Checkout History & Rollback

Every checkout keeps a **history** (reflog) of the snapshots it has pointed to — each update you apply adds a new entry. You can see this timeline under Settings → Data → Checkouts → History.

If a new data version causes problems — for example a fit no longer loads or the data looks wrong — you can **roll back**: pick an earlier entry in the history and revert the checkout to it. The checkout points back to the previous snapshot without downloading everything again, since earlier data is still stored locally.

Rollback is safe and reversible. Updating again later simply moves the checkout forward to the latest snapshot and records another history entry.

Note that rollback changes the data version, not your fits — your saved fits are kept separately and are never modified by reverting data.

- Settings → Data → Checkouts → tap the history icon on a checkout.
- Choose an earlier snapshot and confirm the revert.
- Roll back when a fresh update breaks something; update again when a fix is published.
