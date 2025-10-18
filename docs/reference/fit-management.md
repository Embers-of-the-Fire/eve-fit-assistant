# Fit Registry and Management

## Main Logic

All fits are stored locally in the app's storage directory, and won't be loaded until accessed.

The manager is written in [this file](../../lib/storage/fit/manager.dart).

The registry manager owns a fit registry, which is a list of all fits available in the app.
The registry is stored in `<document>/fittings/registry.json`.

And, when required to load a fit, the manager will load the fit from the disk,
and cache it in memory for future access.
The fit schema is defined in [this file](../../lib/storage/fit/schema.dart).

## Fit Registry

The fit registry is a global data structure
that maintains information about all available fits in the application.

Locally it's a json file.

## Fit

A fit is a collection of settings and configurations and the mose importantly the fit (lol).

Locally a fit is a json file with an extra entry in the registry.
The fit's file is stored in `<documents>/fittings/<fitId>.json`,
where the `fitId` is a UUID v4 string.
