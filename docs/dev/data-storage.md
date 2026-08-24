# Application Data Storage and Management

The app uses [`riverpod`](https://riverpod.dev) to manage data.

## Concept, Choice and Suggestion

There're four layers of data storage:
- [Global state](#global-state), including [settings (`AppSettingService`)](../../apps/eve-fit-assistant/lib/storage/setting/setting.dart).
  The global state is used across the app, and should be loaded at the app start.
  Any error in global state is considered critical,
  and should be immediately available once the splash screen is dismissed.
- [Global data](#global-data), including [the repository system (`RepoService`)](../../apps/eve-fit-assistant/lib/storage/repo/service.dart).
  This layer is also error-critical, but can be loaded after the app start.
  The app should show a loading indicator when the user tries to access this data.
- [Service data](#service-data), loaded by managers, is offered as a global provider (in riverpod).
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
   For example, type data are served through `RepoCollectionService`.
3. If the state will change, a `manager` class should be created to handle the state changes.
   This manager class is responsible for updating the state and notifying any listeners of changes.
   For example, `FitManager` manages the fit data state.
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

- `RepoService`: The content-addressed repository service.
  It owns checkout lifecycle, channel discovery, and resource fetching.
  See [Storage Layer](../agents/storage.md) for the repository system.
- `CheckoutRegistryService`: The checkout registry manager.
  The registry is stored in `checkouts/checkouts.json` under the repository storage.
  This service offers the checkout registry data interface.
- `FitManager`: The overall fit data manager. This provider offers no direct data interface.
- `FitRegistryManager` > `FitRegistry`: The fit registry manager.
  The registry is stored in `<documents>/fittings/registry.json`.
  The registry is versioned through the fit persistence layer.
  This provider offers the fit registry data interface.
  The access to operate on the registry is limited to the `FitManager`.
  See [Fit Storage and Versioning](./fit-storage.md) for the on-disk format.

### Service Data

- `RepoCollectionService`: The structural type-data source.
  It pre-loads ships, skills, items, and icons from the active checkout's `ResourceIndex`.
- `LocalizationDbService`: Resolves localized strings from the active checkout's
  prebuilt `localization.db`; `localizedNameProvider` resolves `(id, locale)` on demand.
- `FitService` > `FitServiceStatus`: The fit service.
  This provider offers the fit service status data interface.
  Fit files are decoded through the versioned fit persistence layer,
  and legacy alpha payloads are eagerly normalized when loaded.
  The value might be changed by the `FitManager`.
- `FitEmulatorService` > `FitEmulatorState`: The wrapper over backend engine service.
  See [this file](../../apps/eve-fit-assistant/lib/storage/fit/service.dart) for details.
- `NativeFitEngineService` > `NativeFitEngineState`: The backend(native) engine service.
  See [this dart port](../../apps/eve-fit-assistant/lib/storage/fit/service.dart)
  and [this rust source](../../apps/eve-fit-assistant/rust/src/api/server.rs) for more information.
