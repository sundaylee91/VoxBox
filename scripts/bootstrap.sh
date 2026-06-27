#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${GREEN}[VoxBox]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

log "Checking Xcode installation…"
if ! xcode-select -p &>/dev/null; then
    err "Xcode not found. Install from https://developer.apple.com/xcode/"
    exit 1
fi
log "✅ Xcode found: $(xcode-select -p)"

log "Checking Homebrew…"
if ! command -v brew &>/dev/null; then
    warn "Homebrew not found. Installing…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
fi
log "✅ Homebrew ready"

PYTHON_PATH=""
for candidate in /opt/homebrew/bin/python3.12 /usr/local/bin/python3.12 /opt/homebrew/bin/python3 /usr/bin/python3; do
    if [[ -x "$candidate" ]]; then
        version=$("$candidate" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
        major=$(echo "$version" | cut -d. -f1)
        minor=$(echo "$version" | cut -d. -f2)
        if [[ "$major" -eq 3 && "$minor" -ge 10 && "$minor" -le 12 ]]; then
            PYTHON_PATH="$candidate"; break
        fi
    fi
done

if [[ -z "$PYTHON_PATH" ]]; then
    log "Installing Python 3.12 via Homebrew…"
    brew install python@3.12
    PYTHON_PATH="/opt/homebrew/bin/python3.12"
fi
log "✅ Python: $($PYTHON_PATH --version)"

VENV_DIR="${PWD}/.venv"
if [[ ! -d "$VENV_DIR" ]]; then
    log "Creating virtual environment…"
    "$PYTHON_PATH" -m venv "$VENV_DIR"
fi
source "${VENV_DIR}/bin/activate"

log "Installing voxcpmane2…"
pip install --upgrade pip
pip install voxcpmane2
log "✅ voxcpmane2 installed: $(pip show voxcpmane2 | grep Version | awk '{print $2}')"

log "Verifying installation…"
python -c "import voxcpmane; print('✅ voxcpmane module loaded successfully')"

echo ""
log "🎉 VoxBox development environment is ready!"
echo ""
log "Next: open VoxBox.xcodeproj in Xcode and press ⌘R"
