#!/bin/bash

# OpenROAD + OpenROAD-flow-scripts + OpenRAM — minimal Linux setup
# Skips steps when tools are already installed. Single OpenROAD build via flow (no 3-hour double build).

set -e

echo " OpenROAD + Flow + OpenRAM (minimal setup)"
echo "==========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status()  { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
print_header()  { echo -e "${BLUE}[SETUP]${NC} $1"; }
print_skip()    { echo -e "${GREEN}[SKIP]${NC} $1 (already present)"; }

# Parse options
SKIP_OPENRAM_TEST=true
RUN_APT_UPGRADE=false
CLEAR_ENV=false
INSTALL_DIR="${OPENROAD_INSTALL_DIR:-$HOME/openroad-setup}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --test-openram)  SKIP_OPENRAM_TEST=false; shift ;;
        --upgrade)       RUN_APT_UPGRADE=true; shift ;;
        --fresh)         CLEAR_ENV=true; shift ;;
        --install-dir)   INSTALL_DIR="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--test-openram] [--upgrade] [--fresh] [--install-dir DIR]"
            echo "  --test-openram   Run OpenRAM example after install (adds ~25 min)"
            echo "  --upgrade        Run 'apt upgrade' (slower, more complete)"
            echo "  --fresh          Unset OpenROAD/OpenRAM env vars so install is not skipped"
            echo "  --install-dir    Install to DIR (default: \$HOME/openroad-setup)"
            exit 0 ;;
        *) shift ;;
    esac
done

# Clear paths so we don't skip steps due to old env (restart from top)
if [[ "$CLEAR_ENV" == true ]]; then
    print_status "Clearing OpenROAD/OpenRAM env vars for fresh run..."
    unset OPENROAD_HOME OPENROAD_FLOW_HOME OPENROAD_EXE YOSYS_EXE
    unset OPENRAM_ROOT OPENRAM_HOME OPENRAM_TECH
    # Remove common install paths from PATH so 'openroad' / 'yosys' aren't found from old installs
    INSTALL_DIR_ABS="$(cd -P "$INSTALL_DIR" 2>/dev/null && pwd)" || true
    if [[ -n "$INSTALL_DIR_ABS" ]]; then
        export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v "$INSTALL_DIR_ABS" | tr '\n' ':' | sed 's/:$//')"
    fi
    print_status "Env cleared. Proceeding with full install checks."
fi

# --- Checks: already installed? ---
has_openroad() {
    if command -v openroad &>/dev/null; then
        openroad -version &>/dev/null && return 0
    fi
    return 1
}

has_yosys() {
    command -v yosys &>/dev/null && yosys -version &>/dev/null
}

# Parse Yosys version (e.g. "0.60" from "Yosys 0.60 (git sha1 ...)")
get_yosys_version() {
    local v
    v=$(yosys -version 2>/dev/null | sed -n 's/^Yosys \([0-9]*\.[0-9]*\).*/\1/p')
    echo "$v"
}

# Return 0 if system Yosys is >= 0.58 (flow requirement)
yosys_version_ok() {
    local v
    v=$(get_yosys_version)
    [[ -z "$v" ]] && return 1
    # Compare major.minor: 0.58+ is ok
    local major minor
    major=${v%%.*}
    minor=${v#*.}; minor=${minor%%.*}
    [[ "$major" -gt 0 ]] && return 0
    [[ "$minor" -ge 58 ]] && return 0
    return 1
}

has_flow_env() {
    [[ -n "$OPENROAD_FLOW_HOME" && -f "$OPENROAD_FLOW_HOME/env.sh" ]] && return 0
    [[ -d "$INSTALL_DIR/openroad-flow-scripts" && -f "$INSTALL_DIR/openroad-flow-scripts/env.sh" ]] && return 0
    return 1
}

# Only skip OpenRAM if it's already in *this* install dir (not elsewhere via OPENRAM_HOME)
has_openram() {
    if [[ -d "$INSTALL_DIR/OpenRAM/compiler" ]]; then
        PYTHONPATH="$INSTALL_DIR/OpenRAM/compiler" python3 -c "import openram" 2>/dev/null && return 0
    fi
    return 1
}

# Resolve flow dir for checks
get_flow_dir() { echo "$INSTALL_DIR/openroad-flow-scripts"; }

# --- Platform ---
if [[ "$(uname -s)" != "Linux" ]]; then
    print_error "This script is for Linux only."
    exit 1
fi

if [[ $EUID -eq 0 ]]; then
    print_error "Do not run as root."
    exit 1
fi

# Validate sudo once so the user is only prompted for password one time
print_status "Checking sudo (you may be asked for your password once)..."
sudo -v

print_status "Install directory: $INSTALL_DIR"
print_status "  (repos and tools go here; use --install-dir DIR to install elsewhere)"
if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    print_status "OS: ${PRETTY_NAME:-$ID $VERSION_ID}"
fi

# Ubuntu: ensure universe for some packages
if [ -f /etc/os-release ] && grep -qi '^ID=ubuntu' /etc/os-release 2>/dev/null; then
    if command -v add-apt-repository &>/dev/null; then
        sudo add-apt-repository -y universe 2>/dev/null || true
    fi
fi

RUN_DIR="$(pwd)"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
INSTALL_DIR="$(pwd)"

# =============================================================================
# Step 1: System dependencies (minimal; flow's setup.sh will add more if needed)
# =============================================================================
print_header "Step 1: System dependencies"

# Check for essentials already installed
NEED_DEPS=false
for cmd in cmake g++ git python3; do
    if ! command -v "$cmd" &>/dev/null; then NEED_DEPS=true; break; fi
done

if [[ "$NEED_DEPS" == "false" ]]; then
    print_skip "cmake, g++, git, python3 already available"
else
    print_status "Updating package lists (no full upgrade for speed)..."
    sudo apt update
    if [[ "$RUN_APT_UPGRADE" == "true" ]]; then
        print_status "Running apt upgrade (can take a while)..."
        sudo apt upgrade -y
    fi
    # Minimal set; flow's setup.sh installs the rest when we run it
    print_status "Installing minimal build and runtime deps..."
    sudo apt install -y \
        build-essential cmake git python3 python3-pip python3-venv \
        wget curl \
        libboost-all-dev libgmp-dev libmpfr-dev libmpc-dev \
        libffi-dev libreadline-dev libsqlite3-dev libbz2-dev \
        libncurses-dev libssl-dev liblzma-dev zlib1g-dev
fi

# =============================================================================
# Step 2: OpenROAD-flow-scripts (builds OpenROAD + Yosys once — no separate OpenROAD build)
# =============================================================================
print_header "Step 2: OpenROAD-flow-scripts (OpenROAD + Yosys)"

FLOW_DIR="$(get_flow_dir)"
if has_openroad && has_yosys; then
    print_skip "OpenROAD and Yosys already on PATH"
    need_flow_build=false
elif [[ -d "$FLOW_DIR" ]] && [[ -f "$FLOW_DIR/env.sh" ]]; then
    # shellcheck source=/dev/null
    if ( source "$FLOW_DIR/env.sh" 2>/dev/null && has_openroad && has_yosys ); then
        print_skip "OpenROAD-flow-scripts already built and working"
        need_flow_build=false
    else
        print_status "Flow dir exists but build may be incomplete; rebuilding..."
        need_flow_build=true
    fi
else
    need_flow_build=true
fi

# Always ensure the flow repo is present (clone if missing) so the user has designs/Makefile even when we skip the build
if [[ ! -d "$INSTALL_DIR/openroad-flow-scripts" ]]; then
    print_status "Cloning openroad-flow-scripts (flow repo with designs, Makefile, etc.)..."
    if ! bash -c "git clone --recursive https://github.com/The-OpenROAD-Project/openroad-flow-scripts.git > \"$INSTALL_DIR/openroad-clone.log\" 2>&1"; then
        print_error "Clone failed. Last 20 lines of log:"
        tail -20 "$INSTALL_DIR/openroad-clone.log" 2>/dev/null || true
        exit 1
    fi
    print_status "Cloning openroad-flow-scripts done."
elif [[ "$need_flow_build" == "false" ]]; then
    print_status "Flow repo already present: $INSTALL_DIR/openroad-flow-scripts"
fi

if [[ -n "$need_flow_build" ]]; then
    if [[ -d /opt/or-tools ]]; then
        print_status "Removing existing /opt/or-tools (may need sudo)..."
        sudo rm -rf /opt/or-tools 2>/dev/null || true
    fi

    cd openroad-flow-scripts
    if [[ -f ./setup.sh ]]; then
        print_status "Running flow setup.sh (installs any missing deps)..."
        sudo ./setup.sh
        print_status "Flow setup.sh done."
    fi

    # If system Yosys >= 0.58, build only OpenROAD and use system Yosys (saves 10–30 min)
    USE_SYSTEM_YOSYS=false
    if has_yosys && yosys_version_ok; then
        YVER=$(get_yosys_version)
        print_status "Using system Yosys ($YVER >= 0.58); building only OpenROAD (skipping Yosys build)."
        USE_SYSTEM_YOSYS=true
    fi

    if [[ "$USE_SYSTEM_YOSYS" == "true" ]]; then
        print_status "Initializing submodules (OpenROAD, etc.)..."
        git submodule update --init --recursive
        print_status "Git submodules done."
        print_status "Building OpenROAD only (~20–45 min)..."
        print_status "  (output logged to openroad-flow-scripts/build_openroad.log)"
        BUILD_LOG="build_openroad.log"
        (
            if [[ -f dev_env.sh ]]; then
                # shellcheck source=/dev/null
                source dev_env.sh
            fi
            PROC=$(nproc --all 2>/dev/null || echo 2)
            INSTALL_PATH="$(pwd)/tools/install"
            mkdir -p "$INSTALL_PATH"
            ./tools/OpenROAD/etc/Build.sh -dir="$(pwd)/tools/OpenROAD/build" -threads="$PROC" -cmake="-D CMAKE_INSTALL_PREFIX=${INSTALL_PATH}/OpenROAD"
            cmake --build tools/OpenROAD/build --target install -j "$PROC"
        ) >> "$BUILD_LOG" 2>&1
        BUILD_EXIT=$?
        if [[ $BUILD_EXIT -eq 0 ]]; then
            print_status "Building OpenROAD only done."
            touch .used_system_yosys 2>/dev/null || true
        else
            print_error "Build failed. Last 30 lines of $BUILD_LOG:"
            tail -30 "$BUILD_LOG" 2>/dev/null || true
            exit 1
        fi
    else
        print_status "Building OpenROAD + Yosys (single build, ~30–60 min)..."
        print_status "  (output logged to openroad-flow-scripts/build_openroad.log)"
        if ./build_openroad.sh --local >> build_openroad.log 2>&1; then
            print_status "Building OpenROAD + Yosys done."
        else
            print_error "Build failed. Last 30 lines of build_openroad.log:"
            tail -30 build_openroad.log 2>/dev/null || true
            exit 1
        fi
    fi
    cd "$INSTALL_DIR"
fi

# =============================================================================
# Step 3: OpenRAM (optional; skip test by default to save ~25 min)
# =============================================================================
print_header "Step 3: OpenRAM"

if has_openram; then
    print_skip "OpenRAM already available"
else
    if [[ ! -d "$INSTALL_DIR/OpenRAM" ]]; then
        cd "$INSTALL_DIR"
        rm -rf OpenRAM 2>/dev/null || true
        print_status "Cloning OpenRAM..."
        git clone https://github.com/VLSIDA/OpenRAM.git
        print_status "Cloning OpenRAM done."
    fi

    cd "$INSTALL_DIR/OpenRAM"
    if ! grep -q "lef_rom_interconnect" technology/freepdk45/tech/tech.py 2>/dev/null; then
        print_status "Patching freepdk45 tech (lef_rom_interconnect)..."
        sed -i '/^m3_stack = ("m3", "via3", "m4")$/a lef_rom_interconnect = ["m1", "m2", "m3", "m4"]' technology/freepdk45/tech/tech.py
    fi

    # OpenRAM needs build-essential, python3-venv; we already did minimal deps
    if ! command -v klayout &>/dev/null; then
        print_status "Installing klayout for OpenRAM..."
        sudo apt install -y klayout 2>/dev/null || true
    fi

    if [[ ! -d "openram_env" ]]; then
        print_status "Creating OpenRAM virtual environment..."
        python3 -m venv openram_env
        # shellcheck source=/dev/null
        source openram_env/bin/activate
        pip install -q "numpy>=1.17.4,<2" matplotlib scipy scikit-learn
        print_status "OpenRAM venv and Python deps done."
        deactivate 2>/dev/null || true
    fi

    if [[ "$SKIP_OPENRAM_TEST" != "true" ]]; then
        print_status "Running OpenRAM example (can take 25+ min)..."
        # shellcheck source=/dev/null
        source openram_env/bin/activate
        if python3 sram_compiler.py macros/sram_configs/example_config_freepdk45.py >> "$INSTALL_DIR/OpenRAM/openram-test.log" 2>&1; then
            print_status "OpenRAM example compile done."
        else
            print_error "OpenRAM example failed. Last 20 lines of log:"
            tail -20 "$INSTALL_DIR/OpenRAM/openram-test.log" 2>/dev/null || true
        fi
        deactivate 2>/dev/null || true
    else
        print_status "Skipping OpenRAM test (use --test-openram to run it)."
    fi
    cd "$INSTALL_DIR"
fi

# =============================================================================
# Step 4: Environment script (source flow's env.sh so openroad + yosys on PATH)
# =============================================================================
print_header "Step 4: Environment script"

cat > "$INSTALL_DIR/setup_environment.sh" << EOF
#!/bin/bash
# OpenROAD + OpenRAM environment (minimal)
# Source this before using openroad, yosys, or the flow.

export OPENROAD_FLOW_HOME="\${OPENROAD_FLOW_HOME:-$INSTALL_DIR/openroad-flow-scripts}"
export OPENRAM_ROOT="\${OPENRAM_ROOT:-$INSTALL_DIR/OpenRAM}"
export OPENRAM_HOME="\$OPENRAM_ROOT/compiler"
export OPENRAM_TECH="\$OPENRAM_ROOT/technology"
export PYTHONPATH="\$OPENRAM_HOME"

# OpenROAD: use flow's built binary
if [[ -x "\$OPENROAD_FLOW_HOME/tools/install/OpenROAD/bin/openroad" ]]; then
    export OPENROAD_EXE="\$OPENROAD_FLOW_HOME/tools/install/OpenROAD/bin/openroad"
    export PATH="\$OPENROAD_FLOW_HOME/tools/install/OpenROAD/bin:\$PATH"
    # Flow's Yosys (if built) so yosys is on PATH after a full build
    if [[ -d "\$OPENROAD_FLOW_HOME/tools/install/yosys/bin" ]]; then
        export PATH="\$OPENROAD_FLOW_HOME/tools/install/yosys/bin:\$PATH"
    fi
fi

# Yosys: use system Yosys if available (flow Makefile uses YOSYS_EXE when set)
if command -v yosys &>/dev/null; then
    export YOSYS_EXE="\$(command -v yosys)"
fi

# If flow's env.sh exists and OpenROAD wasn't found above, source it
if [[ -z "\${OPENROAD_EXE+x}" ]] && [[ -f "\$OPENROAD_FLOW_HOME/env.sh" ]]; then
    source "\$OPENROAD_FLOW_HOME/env.sh"
fi

# Flow's flow/ directory on PATH for 'make'
if [[ -d "\$OPENROAD_FLOW_HOME/flow" ]]; then
    export PATH="\$OPENROAD_FLOW_HOME/flow:\$PATH"
fi

echo "OpenROAD + OpenRAM environment ready."
echo "  OpenROAD-flow-scripts: \$OPENROAD_FLOW_HOME"
echo "  OpenRAM:               \$OPENRAM_ROOT"
echo "  Use: source $INSTALL_DIR/openram_env/bin/activate  (in OpenRAM dir) for OpenRAM Python."
EOF
chmod +x "$INSTALL_DIR/setup_environment.sh"

# OpenRAM tmux helper (use \$ so the script gets literal $1 when run)
cat > "$INSTALL_DIR/run_openram.sh" << 'RUNEOF'
#!/bin/bash
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <config_file.py>"
    echo "Example: $0 my_sram_config.py"
    exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/setup_environment.sh"
SESSION_NAME="openram_$(basename "$1" .py)"
tmux new-session -d -s "$SESSION_NAME"
tmux send-keys -t "$SESSION_NAME" "source $SCRIPT_DIR/setup_environment.sh" Enter
tmux send-keys -t "$SESSION_NAME" "cd \$OPENRAM_ROOT && source openram_env/bin/activate && python3 sram_compiler.py $1" Enter
echo "OpenRAM started. Attach: tmux attach-session -t $SESSION_NAME"
RUNEOF
chmod +x "$INSTALL_DIR/run_openram.sh"

# =============================================================================
# Done
# =============================================================================
print_header "Setup complete"

print_status "Everything was installed to: $INSTALL_DIR"
if [[ "$INSTALL_DIR" != "$RUN_DIR" ]]; then
    print_status "  (install dir differs from where you ran the script — use: cd $INSTALL_DIR)"
fi
print_status ""
print_status "To see the repos:  cd $INSTALL_DIR && ls"
print_status ""
print_status "Next steps:"
if [[ "$INSTALL_DIR" != "$RUN_DIR" ]]; then
    print_status "  1. cd $INSTALL_DIR"
else
    print_status "  1. You are already in the install dir."
fi
print_status "  2. source setup_environment.sh"
print_status "  3. cd \$OPENROAD_FLOW_HOME/flow && make DESIGN_CONFIG=./designs/sky130hd/gcd/config.mk   # quick test"
print_status "  4. For OpenRAM: cd \$OPENRAM_ROOT && source openram_env/bin/activate && python3 sram_compiler.py <config.py>"
print_status ""
print_status "Optional: add to your shell:  source $INSTALL_DIR/setup_environment.sh"
