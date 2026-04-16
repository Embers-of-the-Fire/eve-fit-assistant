---
id: version-1-0-0
---

# Version 1.0.0

## Added

- A new version route under Settings.
- A front-page Updates entry that opens the shared document center.
- Bundled Markdown documents rendered with `markdown_widget`.
- A mixed Workspace feed that now shows announcements, information notes, and version changelogs together.
- An alpha tester guide entry covering supported workflows, known limits, and bundle recovery hints.

## Architecture

- Bundled defaults are loaded from app assets.
- Remote updates are reserved for a separate storage channel.
- Document storage is versioned for future migrations.
