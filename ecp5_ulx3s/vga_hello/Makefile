PROJ=vga_hello

all: $(PROJ).bit

$(PROJ).json: top.v hvsync_generator.v
	yosys -p "synth_ecp5 -top top -json $@" $^

$(PROJ)_out.config: $(PROJ).json
	nextpnr-ecp5 --json $< --textcfg $@ --85k --package CABGA381 --lpf ulx3s_v20.lpf

$(PROJ).bit: $(PROJ)_out.config
	ecppack $< $@	

prog: $(PROJ).bit
	fujprog.exe $<

flash: $(PROJ).bit
	fujprog.exe -j flash $<

clean:
	rm -f *.bit *.config *.json out.txt

.PHONY: prog clean

# To save output: make > out.txt 2>&1   