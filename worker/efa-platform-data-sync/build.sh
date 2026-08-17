#!/bin/bash
# Build phase for the Cloudflare Git integration.
set -e

pnpm ci
pnpx tsc --noEmit
