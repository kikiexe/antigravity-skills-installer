#!/usr/bin/env bash
set -e
set -u

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)       echo "unknown" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "x86_64" ;;
        arm64|aarch64) echo "arm64" ;;
        *) echo "unknown" ;;
    esac
}

OS_TYPE="$(detect_os)"
ARCH_TYPE="$(detect_arch)"
log_info "Detected OS: $OS_TYPE, Architecture: $ARCH_TYPE"

TOOLS_DIR="${TOOLS_DIR:-$HOME/Tools}"
GEMINI_DIR="${GEMINI_DIR:-$HOME/.gemini}"
ANTIGRAVITY_SKILLS_DIR="${ANTIGRAVITY_SKILLS_DIR:-$GEMINI_DIR/antigravity-cli/skills}"
CONFIG_SKILLS_DIR="${CONFIG_SKILLS_DIR:-$GEMINI_DIR/config/skills}"
LOCAL_BIN_DIR="${LOCAL_BIN_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$GEMINI_DIR/config}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$ANTIGRAVITY_SKILLS_DIR"
mkdir -p "$CONFIG_SKILLS_DIR"
mkdir -p "$LOCAL_BIN_DIR"
mkdir -p "$CONFIG_DIR"

safe_link_or_copy() {
    local source_path="$1"
    local target_path="$2"

    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        rm -rf "$target_path"
    fi

    if [ "$OS_TYPE" = "windows" ]; then
        if ln -sfn "$source_path" "$target_path" 2>/dev/null; then
            log_info "Linked $(basename "$target_path")"
        else
            cp -R "$source_path" "$target_path"
            log_info "Copied $(basename "$target_path") (Windows fallback)"
        fi
    else
        ln -sfn "$source_path" "$target_path"
        log_info "Linked $(basename "$target_path")"
    fi
}

log_info "Task 1: Setting up PATH in shell profile..."
add_to_path() {
    local profile_file="$1"
    if [ ! -f "$profile_file" ]; then
        touch "$profile_file"
    fi
    if ! grep -q ".local/bin" "$profile_file"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$profile_file"
        log_success "Added ~/.local/bin to $profile_file"
    fi
}

if [ "$OS_TYPE" = "macos" ]; then
    add_to_path "$HOME/.zshrc"
    add_to_path "$HOME/.zprofile"
fi
add_to_path "$HOME/.bashrc"
add_to_path "$HOME/.bash_profile"

export PATH="$LOCAL_BIN_DIR:$PATH"
log_success "Updated current execution PATH to include $LOCAL_BIN_DIR"

log_info "Task 2: Linking Anti-Slop skills..."
if [ -d "$TOOLS_DIR/anti-slop/skills" ]; then
    for item in "$TOOLS_DIR/anti-slop/skills/"*; do
        if [ -d "$item" ]; then
            name="$(basename "$item")"
            safe_link_or_copy "$item" "$CONFIG_SKILLS_DIR/$name"
            safe_link_or_copy "$item" "$ANTIGRAVITY_SKILLS_DIR/$name"
        fi
    done
    log_success "Anti-slop skills linked."
fi

log_info "Task 3: Linking Ponytail skills..."
if [ -d "$TOOLS_DIR/ponytail/skills" ]; then
    for item in "$TOOLS_DIR/ponytail/skills/"*; do
        if [ -d "$item" ]; then
            name="$(basename "$item")"
            safe_link_or_copy "$item" "$CONFIG_SKILLS_DIR/$name"
            safe_link_or_copy "$item" "$ANTIGRAVITY_SKILLS_DIR/$name"
        fi
    done
    log_success "Ponytail skills linked."
fi

log_info "Task 4: Linking Caveman skills..."
if [ -d "$TOOLS_DIR/caveman/skills" ]; then
    for item in "$TOOLS_DIR/caveman/skills/"*; do
        if [ -d "$item" ]; then
            name="$(basename "$item")"
            safe_link_or_copy "$item" "$CONFIG_SKILLS_DIR/$name"
            safe_link_or_copy "$item" "$ANTIGRAVITY_SKILLS_DIR/$name"
        fi
    done
    log_success "Caveman skills linked."
fi

log_info "Task 5: Setting up rtk binary..."
if ! command -v rtk >/dev/null 2>&1 && [ ! -f "$LOCAL_BIN_DIR/rtk" ]; then
    RTK_VERSION="v1.2.0"
    RTK_URL=""
    if [ "$OS_TYPE" = "linux" ] && [ "$ARCH_TYPE" = "x86_64" ]; then
        RTK_URL="https://github.com/rtk-ai/rtk/releases/download/${RTK_VERSION}/rtk-oss-x86_64-unknown-linux-musl.tar.gz"
    elif [ "$OS_TYPE" = "macos" ] && [ "$ARCH_TYPE" = "arm64" ]; then
        RTK_URL="https://github.com/rtk-ai/rtk/releases/download/${RTK_VERSION}/rtk-oss-aarch64-apple-darwin.tar.gz"
    elif [ "$OS_TYPE" = "macos" ] && [ "$ARCH_TYPE" = "x86_64" ]; then
        RTK_URL="https://github.com/rtk-ai/rtk/releases/download/${RTK_VERSION}/rtk-oss-x86_64-apple-darwin.tar.gz"
    fi

    if [ -n "$RTK_URL" ] && command -v curl >/dev/null 2>&1; then
        log_info "Downloading rtk binary from $RTK_URL..."
        TMP_DIR="$(mktemp -d)"
        if curl -fsSL "$RTK_URL" -o "$TMP_DIR/rtk.tar.gz"; then
            tar -xzf "$TMP_DIR/rtk.tar.gz" -C "$TMP_DIR"
            if [ -f "$TMP_DIR/rtk" ]; then
                cp "$TMP_DIR/rtk" "$LOCAL_BIN_DIR/rtk"
                chmod +x "$LOCAL_BIN_DIR/rtk"
                log_success "rtk binary installed to $LOCAL_BIN_DIR/rtk"
            elif [ -f "$TMP_DIR/rtk-oss" ]; then
                cp "$TMP_DIR/rtk-oss" "$LOCAL_BIN_DIR/rtk"
                chmod +x "$LOCAL_BIN_DIR/rtk"
                log_success "rtk binary installed to $LOCAL_BIN_DIR/rtk"
            fi
        fi
        rm -rf "$TMP_DIR"
    fi
else
    log_success "rtk binary is already available."
fi

log_info "Task 6: Setting up codegraph binary..."
if ! command -v codegraph >/dev/null 2>&1 && [ ! -f "$LOCAL_BIN_DIR/codegraph" ]; then
    if [ -f "$TOOLS_DIR/codegraph/install.sh" ]; then
        log_info "Running codegraph installer..."
        sh "$TOOLS_DIR/codegraph/install.sh" || true
    fi
fi

log_info "Task 7: Configuring graphify tool..."
if ! command -v graphify >/dev/null 2>&1; then
    if command -v pip >/dev/null 2>&1; then
        log_info "Installing graphifyy package via pip..."
        pip install graphifyy || true
    elif command -v pip3 >/dev/null 2>&1; then
        log_info "Installing graphifyy package via pip3..."
        pip3 install graphifyy || true
    fi
fi

log_info "Task 8: Configuring mcp_config.json..."
MCP_CONF="$CONFIG_DIR/mcp_config.json"
DASH_TWO="$(printf '\x2d\x2d')"
if [ ! -f "$MCP_CONF" ]; then
    cat << EOF > "$MCP_CONF"
{
  "mcpServers": {
    "graphify": {
      "command": "graphify-mcp",
      "args": [
        "\${workspace.path}/graphify-out/graph.json"
      ]
    },
    "codegraph": {
      "command": "codegraph",
      "args": [
        "serve",
        "${DASH_TWO}mcp"
      ]
    },
    "context7": {
      "command": "npx",
      "args": [
        "-y",
        "@upstash/context7-mcp"
      ]
    },
    "antislop-contrast": {
      "command": "node",
      "args": [
        "$TOOLS_DIR/anti-slop/.claude-plugin/contrast-mcp-launcher.mjs"
      ]
    }
  }
}
EOF
    log_success "Created MCP server configuration at $MCP_CONF"
else
    log_info "MCP config already exists at $MCP_CONF"
fi

log_info "Task 9: Syncing global agent guidelines (GEMINI.md)..."
if [ ! -f "$GEMINI_DIR/GEMINI.md" ] && [ -f "$SCRIPT_DIR/GEMINI.md" ]; then
    cp "$SCRIPT_DIR/GEMINI.md" "$GEMINI_DIR/GEMINI.md"
    log_success "Copied GEMINI.md to $GEMINI_DIR/GEMINI.md"
fi

log_success "Environment configuration completed."
log_info "Tips: Restart terminal Anda atau jalankan 'source ~/.bashrc' (atau ~/.zshrc) agar PATH langsung aktif."
