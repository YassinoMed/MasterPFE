#!/usr/bin/env bash

set -euo pipefail

INPUT="${1:-docs/architecture/devsecops-mermaid-pas-a-pas.md}"
OUTPUT="${2:-${INPUT%.md}.pdf}"
HTML_OUTPUT="${HTML_OUTPUT:-${OUTPUT%.pdf}.html}"
TITLE="${TITLE:-SecureRAG Hub - Diagrammes DevSecOps}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required command: $1"
    exit 2
  fi
}

find_chrome() {
  local candidates=(
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
    "/Applications/Chromium.app/Contents/MacOS/Chromium"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  if command -v google-chrome >/dev/null 2>&1; then
    command -v google-chrome
    return 0
  fi

  if command -v chromium >/dev/null 2>&1; then
    command -v chromium
    return 0
  fi

  return 1
}

require_command pandoc

if [[ ! -f "${INPUT}" ]]; then
  error "Input Markdown not found: ${INPUT}"
  exit 2
fi

chrome_bin="$(find_chrome || true)"
if [[ -z "${chrome_bin}" ]]; then
  error "No Chromium-compatible browser found for HTML-to-PDF rendering."
  exit 2
fi

mkdir -p "$(dirname "${OUTPUT}")" "$(dirname "${HTML_OUTPUT}")"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

css_file="${tmp_dir}/mermaid-print.css"
after_body="${tmp_dir}/mermaid-init.html"

cat > "${css_file}" <<'CSS'
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  color: #172026;
  line-height: 1.45;
  max-width: 1180px;
  margin: 32px auto;
  padding: 0 28px;
}
h1 {
  border-bottom: 2px solid #172026;
  padding-bottom: 10px;
}
h2 {
  margin-top: 34px;
  padding-top: 12px;
  border-top: 1px solid #d5dbe3;
  page-break-after: avoid;
}
pre {
  white-space: pre-wrap;
  word-break: break-word;
}
code {
  font-family: "SFMono-Regular", Consolas, monospace;
}
.mermaid {
  margin: 18px 0 30px;
  padding: 16px;
  border: 1px solid #cfd7e2;
  border-radius: 6px;
  background: #fbfcfe;
  page-break-inside: avoid;
}
.mermaid svg {
  max-width: 100%;
  height: auto;
}
@media print {
  body {
    margin: 0;
    padding: 0 8mm;
  }
  h2 {
    break-after: avoid;
  }
  .mermaid {
    break-inside: avoid;
  }
}
CSS

cat > "${after_body}" <<'HTML'
<script type="module">
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs";

document.querySelectorAll("pre > code.language-mermaid, pre > code.mermaid, pre.mermaid > code").forEach((code) => {
  const div = document.createElement("div");
  div.className = "mermaid";
  div.textContent = code.textContent;
  const pre = code.closest("pre");
  pre.replaceWith(div);
});

mermaid.initialize({
  startOnLoad: false,
  securityLevel: "loose",
  flowchart: {
    htmlLabels: true,
    curve: "basis"
  },
  sequence: {
    mirrorActors: false
  },
  theme: "default"
});

await mermaid.run({ querySelector: ".mermaid" });
document.body.setAttribute("data-mermaid-rendered", "true");
</script>
HTML

info "Rendering Markdown to HTML with pandoc"
pandoc \
  --from markdown \
  --to html5 \
  --standalone \
  --metadata "title=${TITLE}" \
  --css "${css_file}" \
  --include-after-body "${after_body}" \
  --output "${HTML_OUTPUT}" \
  "${INPUT}"

info "Printing HTML to PDF with ${chrome_bin}"
"${chrome_bin}" \
  --headless=new \
  --disable-gpu \
  --no-sandbox \
  --allow-file-access-from-files \
  --virtual-time-budget=12000 \
  --print-to-pdf="${OUTPUT}" \
  "file://${PWD}/${HTML_OUTPUT}" >/dev/null 2>&1

if [[ ! -s "${OUTPUT}" ]]; then
  error "PDF was not generated or is empty: ${OUTPUT}"
  exit 1
fi

info "HTML written to ${HTML_OUTPUT}"
info "PDF written to ${OUTPUT}"
