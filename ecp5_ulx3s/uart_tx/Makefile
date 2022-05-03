PROJ=uart_tx

all: $(PROJ).bit

$(PROJ).json: top.v uart_tx.v
	yosys -p "synth_ecp5 -top top -json $@" $^

$(PROJ)_out.config: $(PROJ).json
	nextpnr-ecp5 --json $< --textcfg $@ --85k --package CABGA381 --lpf ulx3s_v20.lpf

$(PROJ).bit: $(PROJ)_out.config
	ecppack $< $@	

prog: $(PROJ).bit
	fujprog.exe $<

flash: $(PROJ).bit
	fujprog.exe -j flash $<

sim:
	iverilog -o tb.out -s tb testbench.v uart_tx.v
	vvp tb.out 
	
sim-show:
	gtkwave testbench.vcd   

clean:
	rm -f *.bit *.config *.json out.txt *.vcd

.PHONY: prog clean

# To save output: make > out.txt 2>&1

