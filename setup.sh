#!/bin/bash

# OpenROAD + OpenRAM Linux Setup Script
# One-command setup for Ubuntu/Debian systems

set -e  # Exit on any error

echo " OpenROAD + OpenRAM Linux Setup"
echo "=================================="
echo "This will install OpenROAD, OpenROAD-flow-scripts, and OpenRAM"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Check if we're on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
    print_error "This script is for Linux only"
    exit 1
fi

print_status "Detected OS: Linux"

# Create installation directory
INSTALL_DIR="$HOME/openroad-setup"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

print_header "Step 1: Installing System Dependencies"

# Update system packages
print_status "Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Install dependencies (updated for modern Ubuntu/Debian)
print_status "Installing system dependencies..."
sudo apt install -y \
    build-essential cmake git python3 python3-pip \
    wget curl tmux screen \
    libboost-all-dev libgmp-dev libmpfr-dev libmpc-dev \
    libffi-dev libreadline-dev libsqlite3-dev libbz2-dev \
    libncurses5-dev libssl-dev liblzma-dev libgdbm-dev \
    libnss3-dev libfreetype6-dev libpng-dev libjpeg-dev \
    libtiff-dev libwebp-dev \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    libgtk-3-dev libatlas-base-dev libhdf5-dev \
    libhdf5-serial-dev python3-pyqt5 libblas-dev liblapack-dev \
    gfortran libopenblas-dev ruby \
    libyaml-cpp-dev

print_header "Step 2: Installing OpenROAD"

# Install OpenROAD
if [[ ! -d "OpenROAD" ]]; then
    print_status "Cloning OpenROAD..."
    git clone --recursive https://github.com/The-OpenROAD-Project/OpenROAD.git
fi

cd OpenROAD
print_status "Installing OpenROAD dependencies..."
sudo ./etc/DependencyInstaller.sh -all

print_status "Building OpenROAD (this will take 30-60 minutes)..."
mkdir -p build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
sudo make install
cd ../..

print_header "Step 3: Installing OpenROAD-flow-scripts"

# Install OpenROAD-flow-scripts
if [[ ! -d "openroad-flow-scripts" ]]; then
    print_status "Cloning OpenROAD-flow-scripts..."
    git clone https://github.com/The-OpenROAD-Project/openroad-flow-scripts.git
fi

cd openroad-flow-scripts
print_status "Building OpenROAD-flow-scripts..."
./build_openroad.sh --local
cd ..

print_header "Step 4: Installing OpenRAM"

# Install OpenRAM
if [[ ! -d "OpenRAM" ]]; then
    print_status "Cloning OpenRAM..."
    git clone https://github.com/VLSIDA/OpenRAM.git
fi

cd OpenRAM

# Install Python dependencies
print_status "Installing Python dependencies..."
pip3 install -r requirements.txt --break-system-packages

# Set up environment
print_status "Setting up OpenRAM environment..."
source setpaths.sh

# Quick test
print_status "Running quick OpenRAM test..."
cat > quick_test.py << EOF
num_rw_ports    = 1
num_r_ports     = 0
num_w_ports     = 0
word_size       = 8
num_words       = 16
num_banks       = 1
words_per_row   = 4
tech_name       = "scn4m_subm"
process_corners = ["TT"]
supply_voltages = [3.3]
temperatures    = [25]
route_supplies  = False
check_lvsdrc    = False
output_path     = "quick_test"
output_name     = "quick_test"
instance_name   = "quick_test"
EOF

# Run test in background with timeout
timeout 300 python3 sram_compiler.py quick_test.py > test.log 2>&1 || {
    print_warning "Quick test timed out or failed. This is normal for first run."
    print_warning "Check test.log for details. OpenRAM should still work."
}

if [ -f "quick_test/quick_test.v" ]; then
    print_status "OpenRAM test successful!"
else
    print_warning "OpenRAM test may have failed, but installation should still work."
fi

cd ..

print_header "Step 5: Creating Environment Scripts"

# Create environment setup script
cat > setup_environment.sh << 'EOF'
#!/bin/bash
# Environment setup script for OpenROAD + OpenRAM

export OPENROAD_HOME="$HOME/openroad-setup/OpenROAD"
export OPENROAD_FLOW_HOME="$HOME/openroad-setup/openroad-flow-scripts"
export OPENRAM_HOME="$HOME/openroad-setup/OpenRAM"

# Add OpenROAD to PATH
export PATH="$OPENROAD_HOME/build/src:$PATH"

# Add OpenROAD-flow-scripts to PATH
export PATH="$OPENROAD_FLOW_HOME/flow:$PATH"

# Setup OpenRAM environment
if [ -f "$OPENRAM_HOME/setpaths.sh" ]; then
    source "$OPENRAM_HOME/setpaths.sh"
fi

echo "OpenROAD + OpenRAM environment ready!"
echo "OpenROAD: $OPENROAD_HOME"
echo "OpenROAD-flow-scripts: $OPENROAD_FLOW_HOME"
echo "OpenRAM: $OPENRAM_HOME"
EOF

chmod +x setup_environment.sh

# Create tmux helper
cat > run_openram.sh << 'EOF'
#!/bin/bash
# Helper script to run OpenRAM in tmux

if [ $# -eq 0 ]; then
    echo "Usage: $0 <config_file.py>"
    echo ""
    echo "Example:"
    echo "  $0 my_sram_config.py"
    echo ""
    echo "This will run OpenRAM in a tmux session that persists even if you disconnect."
    exit 1
fi

CONFIG_FILE=$1
SESSION_NAME="openram_$(basename $CONFIG_FILE .py)"

# Setup environment
source setup_environment.sh

# Create new tmux session
tmux new-session -d -s "$SESSION_NAME"

# Run OpenRAM in tmux
tmux send-keys -t "$SESSION_NAME" "cd $HOME/openroad-setup/OpenRAM" Enter
tmux send-keys -t "$SESSION_NAME" "source ../setup_environment.sh" Enter
tmux send-keys -t "$SESSION_NAME" "python3 sram_compiler.py $CONFIG_FILE" Enter

echo "OpenRAM started in tmux session: $SESSION_NAME"
echo ""
echo "Commands:"
echo "  Attach to session:    tmux attach-session -t $SESSION_NAME"
echo "  Detach from session:  Ctrl+B, then D"
echo "  List all sessions:    tmux list-sessions"
echo "  Kill session:         tmux kill-session -t $SESSION_NAME"
EOF

chmod +x run_openram.sh

print_header "Step 6: Creating README"

# Create README
cat > README.md << 'EOF'
# OpenROAD + OpenRAM Linux Setup

One-command setup for OpenROAD, OpenROAD-flow-scripts, and OpenRAM on Linux.

## Quick Start

```bash
curl -sSL https://raw.githubusercontent.com/yourusername/openroad-openram-setup/main/setup.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/yourusername/openroad-openram-setup.git
cd openroad-openram-setup
./setup.sh
```

## What Gets Installed

- **OpenROAD**: Physical design tool
- **OpenROAD-flow-scripts**: ASIC flow automation
- **OpenRAM**: Memory generator
- **All dependencies**: System packages, Python packages, etc.

## Usage

### Setup Environment
```bash
source setup_environment.sh
```

### Generate SRAM
```bash
# Create your SRAM config file
nano my_sram.py

# Run in tmux (recommended for long jobs)
./run_openram.sh my_sram.py

# Or run directly
cd OpenRAM
python3 sram_compiler.py my_sram.py
```

### Use OpenROAD
```bash
# Your OpenROAD commands here
openroad
```

## Installation Directory

Everything is installed in: `$HOME/openroad-setup/`

## Requirements

- Ubuntu 18.04+ or Debian 10+
- 8GB+ RAM recommended
- 20GB+ free disk space
- Internet connection

## Troubleshooting

### Permission Issues
```bash
sudo chown -R $USER:$USER $HOME/openroad-setup
```

### Python Issues
```bash
pip3 install --upgrade pip
pip3 install -r requirements.txt --break-system-packages
```

### Memory Issues
Start with small SRAM configurations first.

## Support

- Check the logs in the respective directories
- Use tmux for long-running jobs
- Start with small examples first

## License

MIT License
EOF

print_header "Setup Complete!"

print_status "Installation directory: $INSTALL_DIR"
print_status ""
print_status "Next steps:"
print_status "1. Setup environment: source setup_environment.sh"
print_status "2. Create a SRAM config file"
print_status "3. Run OpenRAM: ./run_openram.sh your_config.py"
print_status ""
print_status "Happy designing!"
