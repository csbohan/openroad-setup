# OpenROAD One-Command Setup Script

A comprehensive setup script to install OpenROAD, OpenRAM, and OpenROAD-flow-scripts with a single command on Linux systems.

## 🚀 Quick Start

```bash
git clone https://github.com/yourusername/openroad-setup
cd openroad-setup
chmod +x setup_openroad.sh
./setup_openroad.sh
```

## 📋 What This Script Installs

- **OpenROAD** - Open-source RTL-to-GDSII flow
- **OpenRAM** - Open-source memory compiler
- **OpenROAD-flow-scripts** - Complete design flows and examples
- **All dependencies** - System packages, Python packages, and build tools

## 🖥️ Supported Systems

- Ubuntu 20.04 LTS and newer
- Debian 11 and newer
- Other Debian-based distributions

## 📦 Prerequisites

- Linux system with sudo privileges
- Internet connection
- At least 8GB free disk space
- 4GB+ RAM recommended

## 🛠️ Installation

### Method 1: Direct Download and Run
```bash
wget https://raw.githubusercontent.com/yourusername/openroad-setup/main/setup_openroad.sh
chmod +x setup_openroad.sh
./setup_openroad.sh
```

### Method 2: Clone Repository
```bash
git clone https://github.com/yourusername/openroad-setup.git
cd openroad-setup
chmod +x setup_openroad.sh
./setup_openroad.sh
```

## ⚙️ Script Options

The script supports several environment variables for customization:

```bash
# Install to custom directory (default: $HOME/openroad-tools)
INSTALL_DIR=/path/to/install ./setup_openroad.sh

# Skip specific components
SKIP_OPENROAD=1 ./setup_openroad.sh
SKIP_OPENRAM=1 ./setup_openroad.sh
SKIP_FLOW_SCRIPTS=1 ./setup_openroad.sh

# Use specific number of build threads (default: all available cores)
BUILD_THREADS=4 ./setup_openroad.sh
```

## 📁 Installation Structure

After installation, tools are organized as follows:
~/openroad-setup/
'''
├── OpenROAD/ # OpenROAD installation
├── OpenRAM/ # OpenRAM installation
├── openroad-flow-scripts/ # Flow scripts and examples
├── run_openram.sh # Run a openRAM test 
├── setup_enviroment.sh # Enviroment setup script for OpenROAD + OpenRAM
└── README.md 
'''

## 🔧 Environment Setup

The script automatically adds tools to your PATH. After installation, restart your terminal or run:

```bash
source ~/.bashrc
```

Verify installation:
```bash
openroad -version
python3 -c "import openram; print('OpenRAM installed successfully')"
```

## 🚀 Quick Test

### Test OpenROAD
```bash
cd ~/openroad-tools/OpenROAD-flow-scripts
make DESIGN_CONFIG=./designs/sky130hd/gcd/config.mk
```

### Test OpenRAM
```bash
cd ~/openroad-tools/OpenRAM
python3 openram.py examples/configs/config_20nm.py
```

## 📊 Performance Tips

### For Large SRAM Generation
- **RAM**: 8GB+ recommended for large SRAMs (>1MB)
- **CPU**: Single-thread performance matters more than core count
- **Storage**: SSD recommended for faster builds

### Speeding Up OpenRAM
```bash
# Disable DRC/LVS checks for faster generation (testing only)
python3 openram.py -n config.py

# Use smaller test configurations first
python3 openram.py examples/configs/config_20nm_small.py
```

## 🔍 Troubleshooting

### Common Issues

**Permission Denied Errors:**
```bash
sudo chown -R $USER:$USER ~/openroad-tools
```

**Python Package Conflicts:**
```bash
# Use virtual environment
python3 -m venv openram_env
source openram_env/bin/activate
pip install -r requirements.txt
```

**Build Failures:**
```bash
# Check logs
tail -f ~/openroad-tools/logs/setup.log

# Clean and retry
rm -rf ~/openroad-tools
./setup_openroad.sh
```

**Long SSH Sessions:**
```bash
# Use tmux to prevent disconnection
tmux new-session -d -s openroad_setup './setup_openroad.sh'
tmux attach -t openroad_setup
```

### Getting Help

1. Check the installation logs: `~/openroad-tools/logs/`
2. Verify system requirements
3. Try running individual components manually
4. Open an issue with log files attached

## 🧪 Development and Testing

### Testing the Script
```bash
# Test in Docker container
docker run -it ubuntu:22.04
apt update && apt install -y wget
wget https://raw.githubusercontent.com/yourusername/openroad-setup/main/setup_openroad.sh
chmod +x setup_openroad.sh
./setup_openroad.sh
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Test on clean Ubuntu/Debian systems
4. Submit a pull request

## 📚 Useful Resources

- [OpenROAD Documentation](https://openroad.readthedocs.io/)
- [OpenRAM Documentation](https://openram.readthedocs.io/)
- [OpenROAD Flow Scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts)
- [FreePDK45 Technology](https://www.eda.ncsu.edu/freepdk/freepdk45/)

## 🏗️ Example Workflows

### SRAM Generation with OpenRAM
```bash
cd ~/openroad-tools/OpenRAM
# Create config file
cat > my_sram_config.py << EOF
word_size = 32
num_words = 128
technology = "freepdk45"
num_rw_ports = 1
num_r_ports = 0
num_w_ports = 0
EOF

# Generate SRAM
python3 openram.py my_sram_config.py
```

### RTL-to-GDS with OpenROAD
```bash
cd ~/openroad-tools/OpenROAD-flow-scripts
# Use provided examples
make DESIGN_CONFIG=./designs/sky130hd/aes/config.mk
```

## ⚡ Performance Benchmarks

Typical installation times on different systems:

| System | CPU | RAM | Time |
|--------|-----|-----|------|
| Ubuntu 22.04 | 8-core i7 | 16GB | ~45 min |
| Ubuntu 20.04 | 4-core i5 | 8GB | ~75 min |
| Debian 11 | 2-core VM | 4GB | ~120 min |

## 📄 License

This setup script is provided under the MIT License. Individual tools have their own licenses:
- OpenROAD: BSD 3-Clause License
- OpenRAM: BSD 3-Clause License
- OpenROAD-flow-scripts: BSD 3-Clause License

## 🤝 Contributing

Contributions are welcome! Please:
1. Test on multiple Linux distributions
2. Update documentation for new features
3. Follow shell scripting best practices
4. Include error handling and logging

---

**Note**: This is an unofficial setup script. For official installation instructions, refer to the individual project documentation.
