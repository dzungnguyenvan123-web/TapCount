#!/usr/bin/env bash
# Kill running instances, build & package TapCount.app, launch, and verify.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME=${APP_NAME:-TapCount}
APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"
APP_PROCESS_PATTERN="${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
RUN_TESTS=0
RELEASE_ARCHES=""

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for arg in "$@"; do
  case "${arg}" in
    --test|-t) RUN_TESTS=1 ;;
    --release-universal) RELEASE_ARCHES="arm64 x86_64" ;;
    --release-arches=*) RELEASE_ARCHES="${arg#*=}" ;;
    --help|-h)
      log "Usage: $(basename "$0") [--test] [--release-universal] [--release-arches=\"arm64 x86_64\"]"
      exit 0
      ;;
  esac
done

log "==> Killing existing ${APP_NAME} instances"
pkill -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
pkill -x "${APP_NAME}" 2>/dev/null || true

if [[ "${RUN_TESTS}" == "1" ]]; then
  log "==> swift test"
  CLT_FW="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
  CLT_LIB="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
  if [[ ! -d "/Applications/Xcode.app" && -d "${CLT_FW}/Testing.framework" ]]; then
    swift test --package-path "${ROOT_DIR}" --enable-swift-testing --disable-xctest \
      -Xswiftc -F -Xswiftc "${CLT_FW}" \
      -Xlinker -F -Xlinker "${CLT_FW}" \
      -Xlinker -rpath -Xlinker "${CLT_FW}" \
      -Xlinker -rpath -Xlinker "${CLT_LIB}"
  else
    swift test --package-path "${ROOT_DIR}" -q
  fi
fi

HOST_ARCH="$(uname -m)"
ARCHES_VALUE="${HOST_ARCH}"
if [[ -n "${RELEASE_ARCHES}" ]]; then
  ARCHES_VALUE="${RELEASE_ARCHES}"
fi

log "==> Packaging ${APP_NAME}.app"
SIGNING_MODE=adhoc ARCHES="${ARCHES_VALUE}" "${ROOT_DIR}/Scripts/package_app.sh" release

log "==> Launching ${APP_NAME}.app"
if ! open "${APP_BUNDLE}"; then
  log "WARN: open failed; launching binary directly."
  "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1 &
  disown
fi

for _ in {1..10}; do
  if pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1; then
    log "OK: ${APP_NAME} is running."
    exit 0
  fi
  sleep 0.4
done
fail "App exited immediately. Check crash logs in Console.app (User Reports)."
