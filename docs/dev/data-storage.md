# Application Data Storage and Management

The app uses [`riverpod`](https://riverpod.dev) to manage data.

## Concept, Choice and Suggestion

There're four layers of data storage:
- Global state, including [settings (`AppSettingService`)](../../lib/storage/setting/setting.dart).
  The global state is used across the app, and should be loaded at the app start.
  Any error in global state is considered critical,
  and should be immediately available once the splash screen is dismissed.
- Global data, including [bundle manager (`BundleManager`)](../../lib/storage/bundle/manager.dart).
  This layer is also error-critical, but can be loaded after the app start.
  The app should show a loading indicator when the user tries to access this data.
- Bundle data, loaded by the `BundleManager`, is offered as a global provider (in riverpod).
  Error is permitted and the source might change during the app lifetime.
  The app should show a loading indicator when the user tries to access this data,
  and should not let any error break the app.
- Web data, loaded through network requests.
  Error is permitted and the source might change during the app lifetime.
  The app should show a loading indicator when the user tries to access this data,
  and should not let any error break the app.

To properly handle and manage states, the application follows these principles:
1. States (except global states) must be provided through a `Provider` (or its variants).
   This ensures that the state is easily accessible and manageable throughout the app.
2. If the state contains complicated logic, use a `service` to handle the logic.
   This service class is responsible for fetching, updating, and managing the data.
   For example, bundle data are served through `BundleService`.
3. If the state will change, a `manager` class should be created to handle the state changes.
   This manager class is responsible for updating the state and notifying any listeners of changes.
   For example, `BundleManager` manages the bundle data state, or `BundleService`.
4. The `manager` class should be a singleton, ensuring that there is only one instance
   managing the state throughout the app. Use `@riverpodSingleton` to create a singleton provider.
5. The `manager` class do not need to expose data interfaces as the data should be forwarded to
   the state providers themselves.
6. The `manager` class should not depend on any UI components or contexts.
   This ensures that the business logic is separated from the UI logic,
   making the code more modular and easier to maintain.

## Dependencies and Code

### Global State

- `AppSettingService` > `AppSetting`: This contains global app-level settings.
  The settings is stored in `<settingsPath>/settings.json`.
  The global settings might be dependent on consumers that do not have a `Ref` environment,
  So the data is actually maintained in the global singleton.
  However, the `AppSettingService` is also a riverpod singleton for better consistence.
  - `locale (riverpod)`: This is a shortcut of `appSettingService.locale`.

### Global Data

- `BundleManager`: The overall bundle data manager. This provider offers no direct data interface.
- `BundleRegistryManager` > `BundleRegistry`: The bundle registry manager.
  The registry is stored in `<settingsPath>/registry.json`.
  This provider offers the bundle registry data interface.
  The interface to operate on the registry is limited to the `BundleManager`.

### Bundle Data

- `BundleService` > `CurrentBundleStatus` > `BundleMetadata`: The current bundle service.
  This provider offers the current bundle metadata data interface.
  The value might be changed by the `BundleManager`.
- Bundle-specific services, in [`lib/storage/bundle/service`](../../lib/storage/bundle/service):
  - `BundlePaths`: The paths of the current bundle.
    See [this file](../../lib/storage/bundle/service/paths.dart) for details.
  - `BundleLocalization`: Exposed through `bundleLocalization (riverpod)`.
  Use `localization (riverpod)` to access the localized strings.
