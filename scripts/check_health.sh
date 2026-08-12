#!/bin/bash
# Contributor Environment Health Check Script
set -euo pipefail

echo "=========================================="
echo "  Disk Cleaner — Developer Health Check   "
echo "=========================================="
echo

echo -n "[1/4] Checking Operating System... "
OS="$(uname -s)"
echo "$OS"

echo -n "[2/4] Checking Swift Compiler... "
if command -v swiftc >/dev/null 2>&1; then
  SWIFT_VER="$(swiftc --version | head -n1)"
  echo "OK ($SWIFT_VER)"
else
  echo "WARNING: swiftc not found in PATH"
fi

echo -n "[3/4] Checking Code Signing Identity... "
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"[^"]*"' | tr -d '"' || true)"
if [ -n "$IDENTITY" ]; then
  echo "Found ($IDENTITY)"
else
  echo "Ad-hoc (OK for local builds)"
fi

echo -n "[4/4] Checking Build Output Directory... "
mkdir -p out
echo "OK (out/ ready)"

echo
echo "Health Check Complete! Run ./build.sh to build local app & DMG."
