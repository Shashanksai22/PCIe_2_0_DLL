# PCIe 2.0 Data Link Layer (DLL) — RTL Design & UVM Verification

**Author:** Valasa Shashank Sai  
**Repository:** [https://github.com/Shashanksai22/PCIe_2_0_DLL](https://github.com/Shashanksai22/PCIe_2_0_DLL)  
**Toolchain:** Verilator 5.055 | Accellera IEEE 1800.2-2020.3.1 UVM | lcov / genhtml | Yosys 0.33  

---

## Verification Sign-Off Summary

| Metric | Target | Achieved | Status |
| :--- | :--- | :--- | :--- |
| **Regression Suite** | 100% Pass | **18 / 18 Tests PASS** (`0` `UVM_ERROR`, `0` `UVM_FATAL`) | PASS |
| **Functional Coverage** | 100% Bins | **100.00% (`51 / 51` bins)** across 3 covergroups | PASS |
| **RTL Line Coverage** | ≥ 90% | **94.8% (`1004 / 1059` lines)** across 9 RTL modules | PASS |
| **Suite Line Coverage** | ≥ 85% | **90.3% (`2610 / 2890` lines)** across 81 RTL + TB files | PASS |
| **SystemVerilog Assertions** | 0 Failures | **8 Concurrent SVAs (`assert` + `cover`)** — `0` failures | PASS |
| **Static Lint & Synthesis** | Clean Elaboration | **0 Functional Lint Errors**; all 9 RTL modules elaborated in Yosys | PASS |

---

## Architecture & Directory Structure

The DUT (`pcie_dl_top`) implements a full-duplex **PCI Express 2.0 Data Link Layer** supporting 12-bit sequence numbering, incremental 32-bit LCRC generation/checking, 16-bit DLLP CRC, 8-slot Replay Buffer with ACK/NAK & timeout retransmission, and strict PHY TX arbitration (`Replay > DLLP > New TLP`).

```text
PCIe_2_0_DLL/
├── Makefile                    # Automated build, 18-test regression, and lcov/genhtml pipeline
├── README.md                   # Project overview, architecture, and quickstart commands
├── docs/                       # Setup & execution flow guide + 5-part verification decks
├── rtl/                        # Synthesizable SystemVerilog RTL (9 modules)
│   ├── pcie_dl_top.sv          # Top-level Data Link Layer integration
│   ├── pcie_dl_tx.sv           # TX framing, sequence prepending, and payload byte packing
│   ├── pcie_dl_rx.sv           # RX sequence checking, duplicate/out-of-order detection
│   ├── pcie_lcrc_tx.sv         # TX 32-bit LCRC generator
│   ├── pcie_lcrc_rx.sv         # RX incremental 1-DWORD/cycle 32-bit LCRC checker
│   ├── pcie_dllp_ctrl.sv       # ACK/NAK DLLP framing and 16-bit CRC engine
│   ├── pcie_replay_buffer.sv   # 8-slot packet storage for unacknowledged TLPs
│   ├── pcie_replay_ctrl.sv     # ACK retirement, NAK pointer rewind, and replay timer
│   └── pcie_phy_tx_arbiter.sv  # Priority arbiter (Replay > DLLP > TLP)
├── tb/                         # Block-level directed SystemVerilog testbenches (9 TBs)
└── uvm_tb/                     # Full-duplex IEEE 1800.2 UVM testbench
    ├── interfaces/             # pcie_dll_if.sv (clocking blocks + 8 concurrent SVAs)
    ├── packages/               # pcie_dll_pkg.sv
    ├── agent/                  # 4 active/passive agents (TL_TX, TL_RX, PHY_TX, PHY_RX)
    ├── env/                    # pcie_dll_env, pcie_dll_v_seqr, reference-model scoreboard & coverage
    ├── sequences/              # Sequence items & base/directed sequences
    ├── v_sequences/            # 18 coordinated virtual sequences
    ├── test_cases/             # 18 regression UVM test classes
    └── tb_top/                 # Top-level UVM testbench wrapper
