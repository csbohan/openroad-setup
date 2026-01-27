# OpenROAD One-Command Setup Script

A comprehensive setup script to install OpenROAD, OpenRAM, and OpenROAD-flow-scripts with a single command on Linux systems.

## Quick Start

```bash
git clone https://github.com/csbohan/openroad-setup.git
cd openroad-setup
chmod +x setup_openroad.sh
./setup_openroad.sh
```

## What This Script Installs

- **OpenROAD** - Open-source RTL-to-GDSII flow
- **OpenRAM** - Open-source memory compiler
- **OpenROAD-flow-scripts** - Complete design flows and examples
- **All dependencies** - System packages, Python packages, and build tools

## Supported Systems

- Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS (including 24.04.3)
- Debian 11 and newer
- Other Debian-based distributions

## Prerequisites

- Linux system with sudo privileges
- Internet connection
- At least 8GB free disk space
- 4GB+ RAM recommended

## Installation

### Method 1: Clone Repository

```bash
git clone https://github.com/csbohan/openroad-setup.git
cd openroad-setup
chmod +x setup_openroad.sh
./setup_openroad.sh
```

## Installation Structure

After installation, tools are organized as follows:

```
~/openroad-setup/
├── OpenROAD/              # OpenROAD installation
├── OpenRAM/               # OpenRAM installation
├── openroad-flow-scripts/ # Flow scripts and examples
├── run_openram.sh         # Run OpenRAM in tmux
├── setup_environment.sh   # Environment setup script for OpenROAD + OpenRAM
└── README.md
```

## Environment Setup

The script automatically adds tools to your PATH. After installation, run:

```bash
source ~/openroad-setup/setup_environment.sh
```

Or restart your terminal and run the same, or add it to your `~/.bashrc`.

Verify installation:

```bash
openroad -version
python3 -c "import openram; print('OpenRAM installed successfully')"
```

## Quick Test

### Test OpenROAD

```bash
cd ~/openroad-setup/openroad-flow-scripts
source env.sh
cd flow
make DESIGN_CONFIG=./designs/sky130hd/gcd/config.mk
```

(Many other designs are available in the flow scripts.)

### Test OpenRAM

First run may take 25+ minutes.

```bash
cd ~/openroad-setup/OpenRAM
source openram_env/bin/activate
python3 sram_compiler.py macros/sram_configs/example_config_freepdk45.py
```

Or use the `run_openram.sh` helper for long jobs:

```bash
cd ~/openroad-setup
./run_openram.sh macros/sram_configs/example_config_freepdk45.py
```

Example custom config `SRAM_32x128_1rw.py` to add to your `OpenRAM/` directory:

```
cat > SRAM_32x128_1rw.py << EOF
num_rw_ports    = 1
num_r_ports     = 0
num_w_ports     = 0

word_size       = 32
num_words       = 128
num_banks       = 1
words_per_row   = 4

tech_name       = "freepdk45"
process_corners = ["TT"]
supply_voltages = [1.1]
temperatures    = [25]

route_supplies  = True
check_lvsdrc    = True

output_path     = "SRAM_32x128_1rw"
output_name     = "SRAM_32x128_1rw"
instance_name   = "SRAM_32x128_1rw"
EOF
```

Then run: `python3 sram_compiler.py SRAM_32x128_1rw.py`

## Performance Tips

### For Large SRAM Generation

- **RAM**: 8GB+ recommended for large SRAMs (>1MB)
- **CPU**: Single-thread performance matters more than core count
- **Storage**: SSD recommended for faster builds

### Speeding Up OpenRAM

```bash
# Disable DRC/LVS checks for faster generation (testing only)
python3 sram_compiler.py -n config.py

# Use smaller test configurations first
python3 sram_compiler.py macros/sram_configs/example_config_freepdk45.py
```

## Troubleshooting

### Common Issues

**Permission Denied Errors:**

```bash
sudo chown -R $USER:$USER ~/openroad-setup
```

**Python Package Conflicts:**

```bash
# Use the virtual environment created by the script
cd ~/openroad-setup/OpenRAM
source openram_env/bin/activate
pip install -r requirements.txt
```

**Build Failures:**

```bash
# Check logs in the build directories
# OpenROAD: ~/openroad-setup/OpenROAD/build/openroad_build.log
# Flow:     ~/openroad-setup/openroad-flow-scripts/build_openroad.log

# Clean and retry
rm -rf ~/openroad-setup/OpenROAD ~/openroad-setup/openroad-flow-scripts ~/openroad-setup/OpenRAM
./setup_openroad.sh
```

**Long SSH Sessions:**

```bash
# Use tmux to prevent disconnection
tmux new-session -d -s openroad_setup './setup_openroad.sh'
tmux attach -t openroad_setup
```

### Getting Help

1. Check the installation logs in the respective build directories
2. Verify system requirements (Ubuntu 20.04/22.04/24.04 or Debian 11+)
3. Try running individual components manually
4. Open an issue with log files attached

## Development and Testing

### Testing the Script

```bash
# Test in Docker container (Ubuntu 24.04)
docker run -it ubuntu:24.04
apt update && apt install -y git
git clone https://github.com/csbohan/openroad-setup.git
cd openroad-setup
chmod +x setup_openroad.sh
./setup_openroad.sh
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Test on clean Ubuntu/Debian systems (including Ubuntu 24.04)
4. Submit a pull request

## Useful Resources

- [OpenROAD Documentation](https://openroad.readthedocs.io/)
- [OpenRAM Documentation](https://openram.readthedocs.io/)
- [OpenROAD Flow Scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts)
- [FreePDK45 Technology](https://www.eda.ncsu.edu/freepdk/freepdk45/)

## Example Workflows

### SRAM Generation with OpenRAM

```bash
cd ~/openroad-setup/OpenRAM
source openram_env/bin/activate

# Create config file
cat > my_sram_config.py << EOF
word_size = 32
num_words = 128
tech_name = "freepdk45"
num_rw_ports = 1
num_r_ports = 0
num_w_ports = 0
EOF

# Generate SRAM
python3 sram_compiler.py my_sram_config.py
```

### RTL-to-GDS with OpenROAD

```bash
cd ~/openroad-setup/openroad-flow-scripts
source env.sh
cd flow
# Use provided examples
make DESIGN_CONFIG=./designs/sky130hd/aes/config.mk
```

## Performance Benchmarks

Typical installation times on different systems:

| System        | CPU       | RAM  | Time    |
|---------------|-----------|------|---------|
| Ubuntu 24.04  | 8-core i7 | 16GB | ~45 min |
| Ubuntu 22.04  | 8-core i7 | 16GB | ~45 min |
| Ubuntu 20.04  | 4-core i5 | 8GB  | ~75 min |
| Debian 11     | 2-core VM | 4GB  | ~120 min|

## License

This setup script is provided under the MIT License. Individual tools have their own licenses:

- OpenROAD: BSD 3-Clause License
- OpenRAM: BSD 3-Clause License
- OpenROAD-flow-scripts: BSD 3-Clause License

## Contributing

Contributions are welcome. Please:

1. Test on multiple Linux distributions (including Ubuntu 24.04.3)
2. Update documentation for new features
3. Follow shell scripting best practices
4. Include error handling and logging

---

**Note**: This is an unofficial setup script. For official installation instructions, refer to the individual project documentation.
