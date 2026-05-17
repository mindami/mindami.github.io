#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="./external-apps.conf"
ENGINE="host"
STATIC_ROOT="./static"
WORK_ROOT="./.external-apps-work"

usage() {
  cat <<'EOF'
Usage: stage_external_apps.sh [options]

Options:
  --config <path>      Config file path (default: ./external-apps.conf)
  --engine <host|docker>
                       Build engine for install/build commands (default: host)
  --static-root <path> Static root (default: ./static)
  --work-root <path>   Temporary workspace root (default: ./.external-apps-work)
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --engine)
      ENGINE="$2"
      shift 2
      ;;
    --static-root)
      STATIC_ROOT="$2"
      shift 2
      ;;
    --work-root)
      WORK_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$ENGINE" != "host" && "$ENGINE" != "docker" ]]; then
  echo "Invalid engine '$ENGINE'. Use host or docker." >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

mkdir -p "$STATIC_ROOT"
rm -rf "$WORK_ROOT"
mkdir -p "$WORK_ROOT"

cleanup() {
  if [[ "${KEEP_EXTERNAL_APPS_WORKDIR:-0}" != "1" ]]; then
    rm -rf "$WORK_ROOT"
  fi
}
trap cleanup EXIT

sanitize_publish_subpath() {
  local publish_subpath="$1"
  if [[ -z "$publish_subpath" ]]; then
    echo "publish_subpath cannot be empty" >&2
    return 1
  fi
  if [[ "$publish_subpath" = /* ]]; then
    echo "publish_subpath must be relative: $publish_subpath" >&2
    return 1
  fi
  if [[ "$publish_subpath" == *".."* ]]; then
    echo "publish_subpath cannot contain '..': $publish_subpath" >&2
    return 1
  fi
}

resolve_clone_url() {
  local repo="$1"
  local auth="$2"

  if [[ "$repo" == "git@github.com:"* ]]; then
    local repo_path="${repo#git@github.com:}"
    repo_path="${repo_path%.git}"
    if [[ "$auth" == "pat" ]]; then
      if [[ -z "${EXTERNAL_REPO_PAT:-}" ]]; then
        echo "EXTERNAL_REPO_PAT is required for private repo '$repo'" >&2
        return 1
      fi
      echo "https://x-access-token:${EXTERNAL_REPO_PAT}@github.com/${repo_path}.git"
      return 0
    fi
    echo "$repo"
    return 0
  fi

  if [[ "$repo" == https://github.com/* ]]; then
    local without_scheme="${repo#https://github.com/}"
    without_scheme="${without_scheme%.git}"
    if [[ "$auth" == "pat" ]]; then
      if [[ -z "${EXTERNAL_REPO_PAT:-}" ]]; then
        echo "EXTERNAL_REPO_PAT is required for private repo '$repo'" >&2
        return 1
      fi
      echo "https://x-access-token:${EXTERNAL_REPO_PAT}@github.com/${without_scheme}.git"
      return 0
    fi
    echo "https://github.com/${without_scheme}.git"
    return 0
  fi

  if [[ "$repo" == */* && "$repo" != *"://"* ]]; then
    if [[ "$auth" == "pat" ]]; then
      if [[ -z "${EXTERNAL_REPO_PAT:-}" ]]; then
        echo "EXTERNAL_REPO_PAT is required for private repo '$repo'" >&2
        return 1
      fi
      echo "https://x-access-token:${EXTERNAL_REPO_PAT}@github.com/${repo}.git"
      return 0
    fi
    echo "https://github.com/${repo}.git"
    return 0
  fi

  echo "$repo"
}

run_build_commands() {
  local repo_dir="$1"
  local install_cmd="$2"
  local build_cmd="$3"

  if [[ "$ENGINE" == "docker" ]]; then
    docker run --rm \
      -u "$(id -u):$(id -g)" \
      -v "${repo_dir}:/work" \
      -w /work \
      node:lts-bookworm \
      sh -lc "$install_cmd && $build_cmd"
    return
  fi

  (
    cd "$repo_dir"
    bash -lc "$install_cmd && $build_cmd"
  )
}

line_number=0
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line_number=$((line_number + 1))

  if [[ -z "$raw_line" || "$raw_line" =~ ^[[:space:]]*# ]]; then
    continue
  fi

  IFS='|' read -r slug repo ref install_cmd build_cmd output_dir publish_subpath auth <<< "$raw_line"

  if [[ -z "${slug:-}" || -z "${repo:-}" || -z "${ref:-}" || -z "${install_cmd:-}" || -z "${build_cmd:-}" || -z "${output_dir:-}" || -z "${publish_subpath:-}" || -z "${auth:-}" ]]; then
    echo "Invalid config at ${CONFIG_FILE}:${line_number}. Expected 8 fields." >&2
    exit 1
  fi

  if [[ "$auth" != "none" && "$auth" != "pat" ]]; then
    echo "Invalid auth value '${auth}' at ${CONFIG_FILE}:${line_number}. Use none|pat." >&2
    exit 1
  fi

  sanitize_publish_subpath "$publish_subpath"

  clone_url="$(resolve_clone_url "$repo" "$auth")"
  repo_dir="${WORK_ROOT}/${slug}/repo"
  target_dir="${STATIC_ROOT}/${publish_subpath}"

  mkdir -p "$(dirname "$repo_dir")"

  echo "[external-apps] Cloning ${repo} (${ref})"
  git clone --depth 1 --branch "$ref" "$clone_url" "$repo_dir"

  echo "[external-apps] Building ${slug}"
  echo "[external-apps] install: ${install_cmd}"
  echo "[external-apps] build:   ${build_cmd}"
  run_build_commands "$repo_dir" "$install_cmd" "$build_cmd"

  source_dir="${repo_dir}/${output_dir}"
  if [[ ! -d "$source_dir" ]]; then
    echo "Build output directory missing for ${slug}: ${source_dir}" >&2
    exit 1
  fi

  echo "[external-apps] Staging ${slug} to ${target_dir}"
  rm -rf "$target_dir"
  mkdir -p "$target_dir"
  cp -a "${source_dir}/." "$target_dir/"

  echo "[external-apps] Done: ${slug} => ${target_dir}"
done < "$CONFIG_FILE"

echo "[external-apps] All external app artifacts staged successfully."
