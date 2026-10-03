`timescale 1ns/1ps

module tb_fft;
    parameter MAX_STAGES = 10;
    parameter INPUT_STAGE_WIDTH = 4;
    parameter OUTPUT_DATA_WIDTH = 32;
    parameter INPUT_DATA_WIDTH = 16;
    parameter FRAC_BITS = 15;
    parameter BUTTERFLY_FACTOR = 6s;

    parameter INPUT_STAGE = 10; 
    parameter TOTAL_SAMPLES = 4096;

    localparam N = 1 << INPUT_STAGE;
    localparam NUM_FRAMES = TOTAL_SAMPLES / N;

    reg clk;
    reg rst_n;
    reg data_valid;
    reg read_next;
    reg read_done;
    reg [INPUT_STAGE_WIDTH-1:0] input_stage;
    reg signed [INPUT_DATA_WIDTH-1:0] data_in;

    wire in_ready;
    wire out_ready;
    wire signed [OUTPUT_DATA_WIDTH-1:0] output_data_R;
    wire signed [OUTPUT_DATA_WIDTH-1:0] output_data_I;

    reg signed [INPUT_DATA_WIDTH-1:0] mem [0:TOTAL_SAMPLES-1];

    fft #(
        .MAX_STAGES(MAX_STAGES),
        .INPUT_STAGE_WIDTH(INPUT_STAGE_WIDTH),
        .OUTPUT_DATA_WIDTH(OUTPUT_DATA_WIDTH),
        .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
        .FRAC_BITS(FRAC_BITS),
        .BUTTERFLY_FACTOR(BUTTERFLY_FACTOR)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_valid(data_valid),
        .read_next(read_next),
        .read_done(read_done),
        .input_stage(input_stage),
        .data_in(data_in),
        .in_ready(in_ready),
        .out_ready(out_ready),
        .output_data_R(output_data_R),
        .output_data_I(output_data_I)
    );

    always #5 clk = ~clk;

    integer f_in, f_out, r, i, frame;

    initial begin
        clk = 0;
        rst_n = 0;
        data_valid = 0;
        read_next = 0;
        read_done = 0;
        input_stage = INPUT_STAGE;
        data_in = 0;

        f_in = $fopen("sim/input_samples.txt", "r");
        if (f_in == 0) f_in = $fopen("input_samples.txt", "r");
        if (f_in == 0) begin
            $display("Error: cannot open input file");
            $finish;
        end

        for (i = 0; i < TOTAL_SAMPLES; i = i + 1) begin
            r = $fscanf(f_in, "%d\n", mem[i]);
        end
        $fclose(f_in);

        f_out = $fopen("sim/output_results.txt", "w");
        if (f_out == 0) f_out = $fopen("output_results.txt", "w");

        #20;
        rst_n = 1;
        #20;

        for (frame = 0; frame < NUM_FRAMES; frame = frame + 1) begin
            wait (in_ready);
            @(posedge clk);

            for (i = 0; i < N; i = i + 1) begin
                data_valid <= 1;
                data_in <= mem[frame * N + i];
                @(posedge clk);
            end
            data_valid <= 0;
            data_in <= 0;

            wait (out_ready);
            @(posedge clk);

            for (i = 0; i < N; i = i + 1) begin
                $fdisplay(f_out, "%d %d", output_data_R, output_data_I);
                if (i < N - 1) begin
                    read_next <= 1;
                    @(posedge clk);
                    #1;
                    read_next <= 0;
                end
            end
            read_next <= 0;
            @(posedge clk);
            read_done <= 1;
            @(posedge clk);
            read_done <= 0;
            @(posedge clk);
        end

        $fclose(f_out);
        $display("Simulation complete. Output written to sim/output_results.txt");
        $finish;
    end

endmodule
