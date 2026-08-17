#!/bin/bash
# Build phase for the Cloudflare Git integration.
set -e

npm ci
npx tsc --noEmit
