#!/bin/bash
# Delegate build to macOS/build.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
echo "==> Triggering Disk Cleaner Native macOS Build"
bash "$HERE/macOS/build.sh"
