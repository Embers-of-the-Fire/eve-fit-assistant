# v1.0.0-beta.8 Release Notes

This beta adds neutralizer and Nosferatu rates to fit statistics and restores 3D ship model rendering with clearer fallbacks when textured models are unavailable.

## Fitting

- Show neutralizer and Nosferatu rates (GJ/s) in fit attributes, fit images, and exported or shared fit pages

## Ship 3D Models

- Restore ship model rendering and automatically fall back to another available model variant when the preferred one is missing
- Show a “Low quality” badge and disable the texture toggle when only a geometry-only model is available
