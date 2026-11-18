# End-to-End Setup & Execution Guide: Running RTL + IEEE 1800.2 UVM on Verilator

A complete, reproducible workflow for compiling, simulating, debugging waveforms, and measuring functional + line coverage for any **SystemVerilog RTL + UVM Testbench** using open-source tools on Ubuntu / WSL2.

---

## 1. Prerequisites & Toolchain Installation (Ubuntu / WSL2)

### A. System Packages, `lcov`, GTKWave & Yosys
```bash
sudo apt update
sudo apt install -y git make g++ autoconf flex bison perl python3 \
                    libfl2 libfl-dev zlib1g zlib1g-dev ccache \
                    lcov gtkwave yosys