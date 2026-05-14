// tb_i2s_receiver.v
// Testbench for i2s_clk_gen + i2s_receiver.
//
// Simulates two microphones sending known 16-bit samples.
// Left  channel sends 0xABCD
// Right channel sends 0x1234
//
// Run with:
//   iverilog -o tb.out -s tb tb_i2s_receiver.v \
//       ../rtl/i2s_clk_gen.v ../rtl/i2s_receiver.v
//   vvp tb.out
//   gtkwave testbench.vcd

`timescale 1ns/1ps

module tb ();

    // -----------------------------------------------------------------------
    // Clock: simulate 48 MHz (period = 20.833 ns → use 20 ns for simplicity)
    // -----------------------------------------------------------------------
    reg clk = 0;
    always #10 clk = ~clk;  // 50 MHz for simulation speed; ratios are what matter

    reg resetn = 0;

    // Release reset after 100 clocks
    initial begin
        #2000 resetn = 1;
    end

    // -----------------------------------------------------------------------
    // Dump waveforms
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(0, tb);
        // Run long enough for several complete stereo samples
        // One sample = 64 SCK cycles * CLK_DIV*2 = 64 * 48 = 3072 system clocks
        // Simulate 10 samples = 30720 clocks + some margin
        #(3_200_000)
        $display("Simulation complete.");
        $finish;
    end

    // -----------------------------------------------------------------------
    // I2S clock generator under test
    // -----------------------------------------------------------------------
    wire sck;
    wire ws;

    i2s_clk_gen #(
        .CLK_DIV       (24),
        .BITS_PER_FRAME(32)
    ) dut_clk (
        .clk   (clk),
        .resetn(resetn),
        .sck   (sck),
        .ws    (ws)
    );

    // -----------------------------------------------------------------------
    // Simulated I2S microphone
    // Generates a serial data stream matching the I2S protocol.
    //
    // We model a single SD line (as if both mics share it, non-overlapping).
    // Left  data = 16'hABCD  (sent during WS=1)
    // Right data = 16'h1234  (sent during WS=0)
    //
    // Per I2S spec: data changes on SCK falling edge, one cycle after WS edge.
    // -----------------------------------------------------------------------
    reg  sd;

    reg [15:0] left_word  = 16'hABCD;
    reg [15:0] right_word = 16'h1234;

    reg [4:0] sim_bit_cnt;
    reg       sim_ws_prev;
    reg [15:0] sim_shift;

    // Generate sd on falling SCK edges
    always @(negedge sck or posedge clk) begin
        if (!resetn) begin
            sim_bit_cnt  = 0;
            sim_ws_prev  = 0;
            sim_shift    = 0;
            sd           = 0;
        end else begin
            if (ws != sim_ws_prev) begin
                // WS edge: load the appropriate word
                sim_ws_prev = ws;
                sim_bit_cnt = 0;
                if (ws == 1'b1) begin
                    sim_shift = left_word;   // left channel upcoming
                end else begin
                    sim_shift = right_word;  // right channel upcoming
                end
                // First falling edge after WS change: output MSB delay slot (0)
                sd = 1'b0;  // delay bit (don't care / MSB of SPH0645 overhead)
            end else begin
                sim_bit_cnt = sim_bit_cnt + 1;
                if (sim_bit_cnt >= 1 && sim_bit_cnt <= 16) begin
                    // Output MSB first
                    sd = sim_shift[15];
                    sim_shift = sim_shift << 1;
                end else begin
                    sd = 1'b0;
                end
            end
        end
    end

    // -----------------------------------------------------------------------
    // I2S receiver under test
    // -----------------------------------------------------------------------
    wire [15:0] left_data;
    wire [15:0] right_data;
    wire        data_valid;

    i2s_receiver #(
        .DATA_WIDTH    (16),
        .BITS_PER_FRAME(32)
    ) dut_rx (
        .clk       (clk),
        .resetn    (resetn),
        .sck       (sck),
        .ws        (ws),
        .sd        (sd),
        .left_data (left_data),
        .right_data(right_data),
        .data_valid(data_valid)
    );

    // -----------------------------------------------------------------------
    // Monitor: print results each time data_valid pulses
    // -----------------------------------------------------------------------
    integer sample_num = 0;
    always @(posedge clk) begin
        if (data_valid) begin
            sample_num = sample_num + 1;
            $display("Sample %0d:  LEFT=0x%04X (expect 0xABCD)  RIGHT=0x%04X (expect 0x1234)  %s",
                sample_num,
                left_data, right_data,
                (left_data == 16'hABCD && right_data == 16'h1234) ? "PASS" : "FAIL");
        end
    end

endmodule
