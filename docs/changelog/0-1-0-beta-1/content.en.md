# v0.1.0-beta.1 Release Notes

This release includes the changes listed below.

- Remote content pipeline with S3/MinIO storage, publish/import workflows, ETag caching, and session management
- Bundle management with schema versioning, impact analysis, profile validation, and installed verification
- Changelog generation with git-cliff integration and release versioning CLI
- Channel renamed from alpha to testing with cross-platform migration
- App version utilities with minAppVer warnings and system locale detection
- Document storage with unread tracking and startup update notification
- Refined UI with ship hull inspection, adaptive grid layout, and restyled skill editor
- Enhanced developer configuration and environment commands
- Handle empty S3 buckets during publish and remote state fetch
- Derive artifact identifier from bundleId instead of gameServer
- Fix release tooling: flag positioning, branch-scoped tags, and Flutter build properties
- Skip unnecessary S3 bucket creation for S3 target
- Handle stale ETag cache on hot restart
- Treat missing alpha max skill as unavailable and preserve bundle title in narrow layouts
- Define remote content storage contract and document local baseline
- Update runtime and build dependencies
- Rename package identifier, update origin URLs, and remove legacy S3 rollback logic
- Update developer documentation and add MinIO CLI to dev environment