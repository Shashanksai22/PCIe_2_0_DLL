# End-to-End Setup & Execution Guide: Running RTL + IEEE 1800.2 UVM on Verilator

A complete, reproducible workflow for setting up Windows Subsystem for Linux (WSL2), installing open-source EDA tools, compiling SystemVerilog RTL with an IEEE 1800.2 UVM testbench, running regressions, and generating line and functional coverage reports.

---

## 0. Starting from Windows: Installing WSL2 (Ubuntu)

If you are on Windows and have never used Linux/WSL before, follow the official Microsoft installation guide or run the single setup command below:

* **Official Microsoft WSL Setup Guide:** [https://learn.microsoft.com/en-us/windows/wsl/install](https://learn.microsoft.com/en-us/windows/wsl/install)

### Quick Installation Steps
1. Open **Windows PowerShell** or **Command Prompt** as **Administrator**.
2. Run:
   ```powershell
   wsl --install
   ```
3. **Restart your computer** when prompted.
4. After rebooting, an **Ubuntu** terminal window will open automatically—create a Linux **username** and **password** when asked.
5. *(Recommended)* Install **Visual Studio Code** on Windows along with the official **WSL extension** (`ms-vscode-remote.remote-wsl`), then type `code .` inside your Ubuntu terminal to edit files and run simulations seamlessly.

---

## 1. Prerequisites & Toolchain Installation (Ubuntu / WSL2)

### A. Install System Dependencies (`lcov`, GTKWave, Yosys, Build Tools)
Open your Ubuntu (WSL) terminal and run:
```bash
sudo apt update
sudo apt install -y git make g++ autoconf flex bison perl python3 \
                    libfl2 libfl-dev zlib1g zlib1g-dev ccache \
                    lcov gtkwave yosys
```

### B. Build and Install Verilator (`v5.055+` with `--timing`)
```bash
cd ~
git clone [https://github.com/verilator/verilator.git](https://github.com/verilator/verilator.git)
cd verilator
autoconf
./configure
make -j$(nproc)
sudo make install
verilator --version
```

### C. Install Accellera UVM (`1800.2-2020.3.1`)
1. Download the official Accellera `1800.2-2020.3.1` library from [accellera.org](https://www.accellera.org/downloads/standards/uvm) and extract it to your home directory at `~/1800.2-2020.3.1`.
2. Configure your environment variable in `~/.bashrc`:
   ```bash
   echo 'export UVM_HOME=$HOME/1800.2-2020.3.1' >> ~/.bashrc
   source ~/.bashrc
   ```

---

## 2. Project Directory Structure Standard

Organize any standard RTL + UVM testbench project with this directory layout:
```text
my_project/
├── Makefile
├── README.md
├── rtl/                  # Synthesizable RTL modules (.sv)
├── tb/                   # Block-level directed testbenches
└── uvm_tb/               # UVM Environment
    ├── interfaces/       # Interfaces and SVA assertions
    ├── packages/         # UVM package definitions
    ├── agent/            # Drivers, monitors, sequences, sequencers
    ├── env/              # Scoreboard, environment, virtual sequencer
    ├── test_cases/       # Individual test classes
    └── tb_top/           # Top-level testbench wrapper
```

---

## 3. Compilation, Simulation & Coverage Execution Flow

### Step 1: Compile RTL and UVM Testbench into C++ Simulation Binary
Pass the UVM source, include paths, timing flags, and code instrumentation flags to Verilator:
```bash
verilator --binary --timing -j 0 \
  --coverage-line --coverage-toggle \
  -Wno-fatal +define+UVM_NO_DPI \
  +incdir+$UVM_HOME/src \
  $UVM_HOME/src/uvm_pkg.sv \
  rtl/*.sv \
  uvm_tb/interfaces/pcie_dll_if.sv \
  uvm_tb/packages/pcie_dll_pkg.sv \
  uvm_tb/tb_top/tb_top.sv \
  --top-module tb_top
```

### Step 2: Run Simulations and Save Coverage Logs
Execute your compiled binary, specifying the desired UVM test name and logging path:
```bash
mkdir -p cov_logs cov_report logs

# Run a sample test case
./obj_dir/Vtb_top +UVM_TESTNAME=full_duplex_random_regression_test \
  +verilator+coverage+file+cov_logs/full_duplex.dat
```

### Step 3: Merge Coverage and Generate HTML Report
Use Verilator coverage tools and `lcov` to filter out library code and produce a clean HTML summary:
```bash
# Merge raw test logs into a unified info file
verilator_coverage --write-info cov_report/all.info cov_logs/*.dat

# Remove standard library and UVM internal code from metrics
lcov --remove cov_report/all.info '*/1800.2-2020.3.1/*' '*/verilator/include/*' -o cov_report/clean.info

# Generate browser-viewable HTML coverage report
genhtml cov_report/clean.info --output-directory cov_report/html
```

---

## 4. Waveform Debugging with GTKWave

If compiled with tracing enabled (`--trace`), simulations generate a `.vcd` waveform file in the root directory. Open and inspect signals using:
```bash
gtkwave dump.vcd &
```
