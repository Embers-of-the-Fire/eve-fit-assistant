# Bundle Registry

The bundle registry is a global data structure
that maintains information about all available bundles in the application.
It is managed by the `BundleRegistryManager` class, which is a singleton provider in Riverpod.

The config file is stored in `<resourcesPath>/bundles.json`.

See [this dart file](../../lib/storage/bundle/manager.dart) for more details.

## Multi-Bundle Alpha Scope

The app can install multiple bundle directories, but it still runs against a single globally active
bundle at a time. The active bundle id is stored as `selectedBundleId` in the bundle registry.

Importing a bundle does not automatically switch the active bundle if another bundle is already
selected. Testers must explicitly select a different installed bundle before the rest of the app
starts reading from it.
