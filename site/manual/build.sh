#!/bin/bash
set -e

# Go to project root.
cd ../..

# Build the site's content
python3 ./x.py build site-manual

# Build the site
cd ./site/manual
pnpm build

