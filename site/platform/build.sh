#!/bin/sh
set -e

cd "$(dirname "$0")/../.."
pnpm install --frozen-lockfile
pnpm --filter efa-proto-ts generate
pnpm --filter efa-platform build
