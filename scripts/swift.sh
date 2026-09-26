#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
mkdir -p .build/module-cache .build/cache .build/config .build/security
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_ROOT/.build/module-cache"
SWIFT_SUBCOMMAND="${1:-build}"
if [ "$#" -gt 0 ]; then shift; fi
EXTRA_FLAGS=()
# Standalone Command Line Tools ship Swift Testing, but some SwiftPM releases
# do not add its framework and macro search paths automatically.
DEVELOPER_PATH="$(xcode-select -p)"
TEST_FRAMEWORKS="$DEVELOPER_PATH/Library/Developer/Frameworks"
if [ "$SWIFT_SUBCOMMAND" = test ] && [ -d "$TEST_FRAMEWORKS/Testing.framework" ]; then
  EXTRA_FLAGS+=(--disable-xctest
    -Xswiftc -F -Xswiftc "$TEST_FRAMEWORKS"
    -Xlinker -F -Xlinker "$TEST_FRAMEWORKS"
    -Xlinker -rpath -Xlinker "$TEST_FRAMEWORKS"
    -Xlinker -rpath -Xlinker "$DEVELOPER_PATH/Library/Developer/usr/lib")
  TEST_PLUGINS="$(dirname "$(dirname "$(xcrun --find swift)")")/lib/swift/host/plugins/testing"
  if [ -d "$TEST_PLUGINS" ]; then
    EXTRA_FLAGS+=(-Xswiftc -plugin-path -Xswiftc "$TEST_PLUGINS")
  fi
fi
# No package dependencies or plugins. Keep all caches inside the project;
# disabling SwiftPM's nested sandbox also permits builds in restricted shells.
exec xcrun swift "$SWIFT_SUBCOMMAND" --disable-sandbox \
  --scratch-path "$PROJECT_ROOT/.build" --cache-path "$PROJECT_ROOT/.build/cache" \
  --config-path "$PROJECT_ROOT/.build/config" --security-path "$PROJECT_ROOT/.build/security" \
  ${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"} "$@"
