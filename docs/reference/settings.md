# App Setting List

> This file is for reference only and is not public documentation for end users.

The settings is defined in `storage/setting/setting.dart > AppSetting` class
and is stored in `<documents>/settings/settings.json`.

## Table of Contents

- [General](#general)
  - [Locale](#locale)
- [Develop](#develop)
  - [Enable Debug Log](#enable-debug-log)

## General

General settings for the app.

### Locale

The language of the app. This will also affect the locale used for formatting dates and numbers.

- Key: `locale`
- Type: [`String (enum Locale)`](../../lib/config/locale.dart)
- Possible Values: See [`efa.config.toml > localizations.supported`](../../efa.config.example.toml).

## Develop

This section is some advanced settings.

**DO NOT CHANGE UNLESS YOU KNOW WHAT YOU ARE DOING.**

### Enable Debug Log

Enable debug log for troubleshooting.
This will log more detailed information to help diagnose issues.

End users might be asked to enable this by support staff when troubleshooting issues.

- Key: `enableDebugLog`
- Type: `bool`
- Default: `false`
