# Makefile for ice40up5k/i2s_mic
# Uses open-source iCEstorm toolchain: yosys, nextpnr-ice40, icepack, iceprog

PROJECT  = i2s_mic
DEVICE   = up5k
PACKAGE  = sg48

RTL_DIR  = rtl
TB_DIR   = tb

SOURCES  = $(RTL_DIR)/top.v \
           $(RTL_DIR)/i2s_clk_gen.v \
           $(RTL_DIR)/i2s_receiver.v \
           $(RTL_DIR)/uart_tx.v \
           $(RTL_DIR)/debounce.v

PCF      = constraints/pins.pcf

# Output files
JSON     = $(PROJECT).json
ASC      = $(PROJECT).asc
BIN      = $(PROJECT).bin

# -----------------------------------------------------------------------
# Default target: synthesise, place-and-route, pack
# -----------------------------------------------------------------------
all: $(BIN)

$(JSON): $(SOURCES)
	yosys -p "synth_ice40 -top top -json $(JSON)" $(SOURCES)

$(ASC): $(JSON) $(PCF)
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) \
	    --json $(JSON) --pcf $(PCF) --asc $(ASC)

$(BIN): $(ASC)
	icepack $(ASC) $(BIN)

# -----------------------------------------------------------------------
# Upload to FPGA
# -----------------------------------------------------------------------
prog: $(BIN)
	iceprog $(BIN)

# -----------------------------------------------------------------------
# Simulation — I2S receiver testbench
# -----------------------------------------------------------------------
sim:
	iverilog -o tb.out -s tb \
	    $(TB_DIR)/tb_i2s_receiver.v \
	    $(RTL_DIR)/i2s_clk_gen.v \
	    $(RTL_DIR)/i2s_receiver.v
	vvp tb.out

sim-wave: sim
	gtkwave testbench.vcd &

# -----------------------------------------------------------------------
# Clean
# -----------------------------------------------------------------------
clean:
	rm -f $(JSON) $(ASC) $(BIN) tb.out testbench.vcd

.PHONY: all prog sim sim-wave clean
