# v1.0.0-beta.3 Release Notes

This beta fixes Android update handling: builds for all device architectures now share a consistent version code, and the app correctly compares beta versions when checking for updates.

## Fixes

- Fix Android updates not being recognized when installing a build made for a different device architecture
- Fix the app misjudging prerelease versions when checking for updates, e.g. treating a beta as newer than the final release
