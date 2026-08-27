# v0.11.0 Release Notes

This release includes the changes listed below.

## Fit Snapshots and Sharing

- Create a snapshot of any fit to capture and display its full configuration
- Uploading a fit is now a dedicated Share action
- Snapshots embed stable, content-addressed item icons so they render consistently everywhere

## Community Platform

- New [community platform site](https://platform.efa-tech.dev/) for posting and discussing fits
- Fit posts show the rendered fit snapshot instead of raw data
- Redesigned front page as an explore dashboard for browsing shared fits
- Registered fit links addressed by fit hash, with faster page loads through edge caching
- Open shared fits directly in the app from a fit post page
- Sign up and sign in with email and password, both on the site and in the app
- Posts are linked to your account, with role-based management of creation and deletion
- Comment on fit posts using Markdown
- New platform feedback channel and bilingual legal and security notices

## Fixes

- Fix charge counts being computed with tiny floating-point errors
