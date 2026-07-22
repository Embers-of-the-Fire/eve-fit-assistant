# v0.2.0 Release Notes

This release introduces a welcome wizard for first-time setup, in-app update detection with release notes and direct download, an announcements page, and a redesigned version info page. Data management now supports per-checkout and batch updates with generation history and revert, and data downloads are significantly faster and more reliable thanks to a new download pipeline and improved caching.

## New

- Welcome wizard for first-time setup, now showing download speed during data download
- App updates: the app now detects new versions, shows version details and release notes in the update dialog, and supports downloading the new version directly, with a manual download page listing available artifacts and recommendations
- Announcements page for viewing official notices
- Data management: check data update status per checkout, update individually or in batch, and browse per-server generation history with support for reverting to a previous generation
- Redesigned version info page with localization support; tap the app version 5 times to enable developer mode and access developer tools
- Feedback dialog that appears after extended use, with follow-up actions

## Improved

- Significantly faster and more reliable data downloads through a high-throughput download pipeline with connection pooling, prioritization of large files, and better caching
- Reduced network usage by skipping re-download of unchanged announcements and remote content
- Faster app startup and data migration
- Storage system upgraded to Schema V2

## Fixed

- New app versions were not detected on first launch
- Tappable links in item descriptions did not respond to taps
