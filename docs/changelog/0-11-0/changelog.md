## [v0.11.0] - 2026-08-27

### Added

- **fit:** create fit snapshot and snapshot display (#369)
- **data:** sync snapshot engine data into Cloudflare D1 (#372)
- **worker:** add remote fit storage & computation service (#373)
- add real uploading to remote service (#374)
- **platform:** add Astro discussion platform site (#375)
- **snapshot-ts:** add Svelte fit snapshot display package (#376)
- **platform:** render fit snapshots with efa-fit-snapshot-ts (#378)
- **platform:** split serving into efa-platform-api front and pure fit store (#379)
- **platform:** improve and align platform snapshot UI (#382)
- **platform:** version-keyed edge caching for all anonymous HTML pages (#383)
- **platform:** absorb fit-share landing into the platform worker (#385)
- **platform:** add registered fit links addressed by fit hash (#386)
- **platform:** add open-in-app trigger on fit post page (#388)
- **platform:** redesign frontpage as explore dashboard (#390)
- **platform:** add email+password auth backend to efa-platform-api (#394)
- **app:** integrate platform account auth (#395)
- migrate to vitest with cloudflare plugin (#397)
- **platform:** wrap platform API behind session facade and auth middleware (#399)
- **platform:** add account auth to the platform site (#400)
- **platform:** link posts to their uploading account (#402)
- add acl package with schema-driven roles and platform integration (#405)
- add managed delete and creation (#406)
- **platform:** remove raw snapshot data display from post detail page (#409)
- **share:** extract fit upload into a dedicated share action (#410)
- **platform:** add markdown discussion comments on posts (#412)
- **platform:** bake content-addressed icon URLs into fit snapshots (#413)
- **platform:** add platform feedback channel and improve topbar layout (#414)
- **platform:** add bilingual legal and security notices to site footer and app account page (#415)

### Chore

- **cf:** set custom domain instead of pattern matching

### Dependencies

- **deps:** move eve-fit-os position

### Documentation

- update agent descriptional docs (#396)
- remove stale references to non-existent files (#401)

### Fixed

- **charge:** window the charge count by 1e-4 (#371)
- **platform:** serve D1 fit snapshot blobs correctly and 500-proof post pages (#380)
- restrict fit storage service (#407)
- **platform:** serve the platform API same-origin in preview builds (#408)

### refactor

- refactor repository to non-root-based monorepo (#365)
- extract shared code and component (#366)
- **fit:** extract shared fit formats into packages/efa_fit (#368)
- **account:** switch Cloudflare Access to service-token auth (#403)
