#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INBOX_DIR="${ROOT_DIR}/posts"
OUTBOX_DIR="${ROOT_DIR}/_posts"
ARCHIVE_DIR="${INBOX_DIR}/processed"
POST_TZ="${POST_TZ:-UTC}"

if [[ ! -d "${INBOX_DIR}" ]]; then
  echo "posts/ directory does not exist. Nothing to publish."
  exit 0
fi

mkdir -p "${OUTBOX_DIR}" "${ARCHIVE_DIR}"

shopt -s nullglob
inbox_files=("${INBOX_DIR}"/*.md)
publish_files=()

if [[ ${#inbox_files[@]} -eq 0 ]]; then
  echo "No Markdown files found in posts/."
  exit 0
fi

for source_file in "${inbox_files[@]}"; do
  if [[ "$(basename "${source_file}")" == "README.md" ]]; then
    continue
  fi
  publish_files+=("${source_file}")
done

if [[ ${#publish_files[@]} -eq 0 ]]; then
  echo "No publishable Markdown files found in posts/."
  exit 0
fi

today="$(TZ="${POST_TZ}" date +%F)"
published_count=0

slugify() {
  local raw="$1"
  local slug

  slug="$(printf '%s' "${raw}" | tr '[:upper:]' '[:lower:]')"
  slug="$(printf '%s' "${slug}" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g')"

  if [[ -z "${slug}" ]]; then
    slug="post"
  fi

  printf '%s' "${slug}"
}

to_title_case() {
  local input="$1"
  printf '%s' "${input}" | sed -E 's/[-_]+/ /g' | awk '{
    for (i = 1; i <= NF; i++) {
      $i = toupper(substr($i, 1, 1)) tolower(substr($i, 2))
    }
    print
  }'
}

extract_title() {
  local source_file="$1"
  local fallback="$2"
  local heading

  heading="$(awk '/^# +/{sub(/^# +/, "", $0); print; exit}' "${source_file}")"

  if [[ -n "${heading}" ]]; then
    printf '%s' "${heading}"
  else
    to_title_case "${fallback}"
  fi
}

strip_front_matter() {
  local source_file="$1"
  local delimiter_count

  delimiter_count="$(grep -c '^---$' "${source_file}" || true)"

  if [[ "$(head -n 1 "${source_file}")" == "---" && ${delimiter_count} -ge 2 ]]; then
    awk '
      BEGIN { in_front_matter = 1; delimiter_seen = 0 }
      NR == 1 && $0 == "---" { delimiter_seen = 1; next }
      in_front_matter && $0 == "---" && delimiter_seen == 1 { in_front_matter = 0; next }
      in_front_matter { next }
      { print }
    ' "${source_file}"
  else
    cat "${source_file}"
  fi
}

for source_file in "${publish_files[@]}"; do
  filename="$(basename "${source_file}")"
  base_name="${filename%.md}"
  slug="$(slugify "${base_name}")"
  title="$(extract_title "${source_file}" "${base_name}")"
  safe_title="${title//\"/\\\"}"

  target_file="${OUTBOX_DIR}/${today}-${slug}.md"
  suffix=1
  while [[ -e "${target_file}" ]]; do
    target_file="${OUTBOX_DIR}/${today}-${slug}-${suffix}.md"
    suffix=$((suffix + 1))
  done

  {
    echo "---"
    echo "layout: post"
    echo "title: \"${safe_title}\""
    echo "date: ${today}"
    echo "categories: blog"
    echo "---"
    echo
    strip_front_matter "${source_file}"
  } > "${target_file}"

  archive_file="${ARCHIVE_DIR}/${filename}"
  if [[ -e "${archive_file}" ]]; then
    archive_file="${ARCHIVE_DIR}/${today}-${base_name}-$(TZ="${POST_TZ}" date +%H%M%S).md"
  fi

  mv "${source_file}" "${archive_file}"

  echo "Published ${filename} -> $(basename "${target_file}")"
  published_count=$((published_count + 1))
done

echo "Published ${published_count} post(s)."
