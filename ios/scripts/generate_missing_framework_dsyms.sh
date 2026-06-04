#!/bin/sh

set -eu

# Only generate missing framework dSYMs for archive/install style builds.
if [ "${ACTION:-}" != "install" ] && [ -z "${ARCHIVE_PATH:-}" ]; then
  exit 0
fi

FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
if [ ! -d "${FRAMEWORKS_DIR}" ]; then
  exit 0
fi

DSYM_OUTPUT_DIR="${ARCHIVE_DSYMS_PATH:-${DWARF_DSYM_FOLDER_PATH:-}}"
if [ -z "${DSYM_OUTPUT_DIR}" ]; then
  exit 0
fi

mkdir -p "${DSYM_OUTPUT_DIR}"

find "${FRAMEWORKS_DIR}" -maxdepth 1 -type d -name '*.framework' | while IFS= read -r framework_dir; do
  framework_name="$(basename "${framework_dir}" .framework)"
  framework_binary="${framework_dir}/${framework_name}"
  framework_dsym="${DSYM_OUTPUT_DIR}/${framework_name}.framework.dSYM"

  if [ ! -f "${framework_binary}" ] || [ -d "${framework_dsym}" ]; then
    continue
  fi

  if ! dwarfdump --uuid "${framework_binary}" >/dev/null 2>&1; then
    continue
  fi

  echo "Generating missing dSYM for ${framework_name}.framework"
  rm -rf "${framework_dsym}"
  dsymutil "${framework_binary}" -o "${framework_dsym}"
done
