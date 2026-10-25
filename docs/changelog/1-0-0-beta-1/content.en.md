# v1.0.0-beta.1 Release Notes

This release introduces stable and testing app release channels and a stable game-data channel, with an easier way to choose your update channel.

## Release and Data Channels

- Add a channel switch dialog for stable and testing app releases, with a startup notice and links that open it directly
- Add a stable game-data channel that receives updates promoted from testing and follows its own release schedule

## Fixes

- Fix data synchronization treating unexpected download failures as missing content; these errors are now reported instead of being silently ignored
