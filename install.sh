#!/usr/bin/env bash
set -e
set -u

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

if ! command -v git >/dev/null 2>&1; then
    log_error "git is required but not found in PATH."
    exit 1
fi

TOOLS_DIR="${TOOLS_DIR:-$HOME/Tools}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

log_info "Tools Destination Directory: $TOOLS_DIR"
mkdir -p "$TOOLS_DIR"

clone_or_pull() {
    local repo_name="$1"
    local repo_url="$2"
    local dest_dir="$TOOLS_DIR/$repo_name"

    if [ -d "$dest_dir/.git" ]; then
        log_info "Updating repository $repo_name..."
        git -C "$dest_dir" pull || true
    else
        log_info "Cloning $repo_name from $repo_url..."
        git clone "$repo_url" "$dest_dir"
    fi
}

log_info "Phase 1: Synchronizing Tools repositories..."

while IFS='|' read -r name url; do
    [ -z "$name" ] && continue
    clone_or_pull "$name" "$url"
done << 'EOF'
anti-slop|https://github.com/miqdadbadjuber/anti-slop.git
ponytail|https://github.com/DietrichGebert/ponytail.git
graphify|https://github.com/Graphify-Labs/graphify.git
rtk|https://github.com/rtk-ai/rtk.git
codegraph|https://github.com/colbymchenry/codegraph.git
context7|https://github.com/upstash/context7.git
Understand-Anything|https://github.com/Egonex-AI/Understand-Anything.git
caveman|https://github.com/JuliusBrussee/caveman.git
EOF

log_success "All repositories synchronized into $TOOLS_DIR."

log_info "Phase 2: Executing configuration script..."
if [ -f "$SCRIPT_DIR/config.bash" ]; then
    TOOLS_DIR="$TOOLS_DIR" bash "$SCRIPT_DIR/config.bash"
else
    log_error "config.bash not found in $SCRIPT_DIR."
    exit 1
fi

log_success "Installation and configuration completed successfully."
