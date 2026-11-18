UVM_HOME ?= /home/shank/1800.2-2020.3.1/src

TESTS = \
	reset_sanity_test \
	single_tlp_tx_test \
	multiple_tlp_tx_test \
	single_tlp_rx_test \
	multiple_tlp_rx_test \
	rx_lcrc_error_nak_test \
	rx_duplicate_seq_test \
	rx_out_of_order_seq_test \
	tx_nak_retransmit_test \
	tx_replay_timeout_test \
	cumulative_ack_test \
	dllp_crc16_error_test \
	phy_arbiter_priority_test \
	backpressure_stall_test \
	replay_buffer_full_test \
	seq_num_rollover_test \
	max_payload_1024dw_test \
	full_duplex_random_regression_test

INCDIRS = \
	+incdir+$(UVM_HOME) \
	+incdir+uvm_tb/interfaces \
	+incdir+uvm_tb/packages \
	+incdir+uvm_tb/agent \
	+incdir+uvm_tb/sequences \
	+incdir+uvm_tb/v_sequences \
	+incdir+uvm_tb/env \
	+incdir+uvm_tb/tests \
	+incdir+uvm_tb/test_cases \
	+incdir+uvm_tb/tb_top

SRCS = \
	$(UVM_HOME)/uvm_pkg.sv \
	rtl/*.sv \
	uvm_tb/interfaces/pcie_dll_if.sv \
	uvm_tb/packages/pcie_dll_pkg.sv \
	uvm_tb/tb_top/tb_top.sv

.PHONY: run compile sim regress report view clean

# Full flow: compile -> run all 18 tests -> merge coverage -> open reports
run: compile sim report view

compile:
	mkdir -p logs cov_logs cov_report
	verilator --binary --sv --timing -Wall -Wno-fatal \
		--coverage \
		--trace --trace-structs \
		-DUVM_NO_DPI \
		$(INCDIRS) $(SRCS) --top-module tb_top

sim:
	@for t in $(TESTS); do \
		echo "=== Running $$t ==="; \
		EXTRA=""; \
		if [ "$$t" = "seq_num_rollover_test" ]; then EXTRA="+ROLLOVER"; fi; \
		./obj_dir/Vtb_top +UVM_TESTNAME=$$t $$EXTRA +verilator+coverage+file+cov_logs/cov_$$t.dat > logs/$$t.log 2>&1; \
		grep -E "UVM_ERROR :|UVM_FATAL :|FUNCTIONAL COVERAGE" logs/$$t.log; \
	done

# Re-run tests + report without recompiling
regress: sim report view

report:
	verilator_coverage --write cov_report/merged.dat cov_logs/cov_*.dat --annotate cov_report/annotated
	verilator_coverage --write-info cov_report/all.info cov_logs/cov_*.dat
	lcov --remove cov_report/all.info '*/1800.2-2020.3.1/*' '*/verilator/include/*' -o cov_report/clean.info
	genhtml cov_report/clean.info --output-directory cov_report/html
	@awk -F'\002|\001' '/covergroup/ && /pcie_dll_scoreboard/ { \
		split($$NF, a, "\x27 "); \
		cnt = a[2] + 0; \
		name = a[1]; \
		sub(/^.*pcie_dll_scoreboard::/, "", name); \
		tot++; if (cnt > 0) hit++; \
		if (name ~ /^cg_tl_tlp/)  { t_tot++; if (cnt > 0) t_hit++; } \
		if (name ~ /^cg_phy_pkt/) { p_tot++; if (cnt > 0) p_hit++; } \
		rows[tot] = sprintf("%-4s (%4d) : %s", (cnt > 0 ? "HIT" : "MISS"), cnt, name); \
	} END { \
		printf "================ CUMULATIVE FUNCTIONAL COVERAGE ================\n"; \
		printf "TOTAL      : %d/%d (%.2f%%)\n", hit, tot, (tot ? 100.0*hit/tot : 0); \
		printf "cg_tl_tlp  : %d/%d (%.2f%%)\n", t_hit, t_tot, (t_tot ? 100.0*t_hit/t_tot : 0); \
		printf "cg_phy_pkt : %d/%d (%.2f%%)\n", p_hit, p_tot, (p_tot ? 100.0*p_hit/p_tot : 0); \
		printf "================================================================\n"; \
		for (i = 1; i <= tot; i++) print rows[i]; \
	}' cov_report/merged.dat > cov_report/summary.txt
	@echo "" >> cov_report/summary.txt
	@echo "================ REGRESSION TEST STATUS ================" >> cov_report/summary.txt
	@grep -H -E "UVM_ERROR :|UVM_FATAL :|FUNCTIONAL COVERAGE" logs/*.log >> cov_report/summary.txt
	@cat cov_report/summary.txt

view:
	-code cov_report/summary.txt
	-explorer.exe "$$(wslpath -w cov_report/html/index.html)"

clean:
	rm -rf obj_dir logs cov_logs cov_report *.vcd