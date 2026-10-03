// input stage:-
// 0 : idle
module fft #(
    parameter MAX_STAGES = 10,
    parameter INPUT_STAGE_WIDTH = 4, // ceil(log2(MAX_STAGES))
    parameter OUTPUT_DATA_WIDTH = 32,
    parameter INPUT_DATA_WIDTH = 16,
    parameter FRAC_BITS = 15,
    parameter BUTTERFLY_FACTOR = 6 // 2^6 = 64
)(                                 // butterfly_factor <= max_stages - 1
    input clk, rst_n, data_valid, read_next, read_done,
    input [INPUT_STAGE_WIDTH-1:0]input_stage,
    input signed[INPUT_DATA_WIDTH-1:0]data_in,
    output in_ready, out_ready,
    output signed [OUTPUT_DATA_WIDTH-1:0] output_data_R, output_data_I

    // to do
);
    localparam MAX_POINTS = 1 << (MAX_STAGES);
    localparam TWD_POINTS = 1 << (MAX_STAGES - 1);
    localparam BUTTERFLIES = 1 << BUTTERFLY_FACTOR;
    localparam INPUT_SIGN_EXT_WIDTH =
        (OUTPUT_DATA_WIDTH > INPUT_DATA_WIDTH) ?
        (OUTPUT_DATA_WIDTH - INPUT_DATA_WIDTH) : 0;

    wire [INPUT_DATA_WIDTH*MAX_POINTS-1:0]input_mem;
    reg signed [OUTPUT_DATA_WIDTH-1:0]RAM_R_arr[0:MAX_POINTS-1];
    reg signed [OUTPUT_DATA_WIDTH-1:0]RAM_I_arr[0:MAX_POINTS-1];

    wire [OUTPUT_DATA_WIDTH*MAX_POINTS-1:0] RAM_R;
    wire [OUTPUT_DATA_WIDTH*MAX_POINTS-1:0] RAM_I;

    wire [INPUT_DATA_WIDTH*TWD_POINTS-1:0]tw_real;
    wire [INPUT_DATA_WIDTH*TWD_POINTS-1:0]tw_imag;

    reg in_loaded, fft_ready;
    wire data_ready, buff_loaded;
    
    fft_input #(
        .MAX_STAGES(MAX_STAGES),
        .INPUT_STAGE_WIDTH(INPUT_STAGE_WIDTH),
        .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH)
    ) input_inst (
        .clk(clk),
        .rst_n(rst_n),
        .data_valid(data_valid),
        .input_stage(input_stage),
        .data_in(data_in),
        .in_loaded(in_loaded),
        .input_mem(input_mem),
        .in_ready(in_ready),
        .data_ready(data_ready)
    );

    fft_output #(
        .MAX_STAGES(MAX_STAGES),
        .MAX_POINTS(MAX_POINTS),
        .OUTPUT_DATA_WIDTH(OUTPUT_DATA_WIDTH)
    ) output_inst (
        .clk(clk),
        .rst_n(rst_n),
        .read_next(read_next),
        .read_done(read_done),
        .fft_ready(fft_ready),
        .IN_RAM_R(RAM_R),
        .IN_RAM_I(RAM_I),
        .output_data_R(output_data_R),
        .output_data_I(output_data_I),
        .buff_loaded(buff_loaded),
        .output_ready(out_ready)
    );

    twiddle_rom tw_rom (
        .tw_real(tw_real),
        .tw_imag(tw_imag)
    );

    wire signed [INPUT_DATA_WIDTH-1:0]input_mem_arr[MAX_POINTS-1:0];

    reg signed [OUTPUT_DATA_WIDTH-1:0]IN_bus_A_R[0:BUTTERFLIES-1];
    reg signed [OUTPUT_DATA_WIDTH-1:0]IN_bus_A_I[0:BUTTERFLIES-1];
    reg signed [OUTPUT_DATA_WIDTH-1:0]IN_bus_B_R[0:BUTTERFLIES-1];
    reg signed [OUTPUT_DATA_WIDTH-1:0]IN_bus_B_I[0:BUTTERFLIES-1];

    reg signed [INPUT_DATA_WIDTH-1:0]IN_bus_T_R[0:BUTTERFLIES-1];
    reg signed [INPUT_DATA_WIDTH-1:0]IN_bus_T_I[0:BUTTERFLIES-1];

    wire signed [OUTPUT_DATA_WIDTH-1:0]OUT_bus_A_R[0:BUTTERFLIES-1];
    wire signed [OUTPUT_DATA_WIDTH-1:0]OUT_bus_A_I[0:BUTTERFLIES-1];
    wire signed [OUTPUT_DATA_WIDTH-1:0]OUT_bus_B_R[0:BUTTERFLIES-1];
    wire signed [OUTPUT_DATA_WIDTH-1:0]OUT_bus_B_I[0:BUTTERFLIES-1];

    wire signed [INPUT_DATA_WIDTH-1:0]tw_real_arr[0:TWD_POINTS-1];
    wire signed [INPUT_DATA_WIDTH-1:0]tw_imag_arr[0:TWD_POINTS-1];
    
    genvar i;

    generate
        for (i = 0; i < MAX_POINTS; i = i +1) begin : MAP_IO
            assign input_mem_arr[i] = input_mem[i*INPUT_DATA_WIDTH +: INPUT_DATA_WIDTH];
            assign RAM_R[i*OUTPUT_DATA_WIDTH +: OUTPUT_DATA_WIDTH] = RAM_R_arr[i];
            assign RAM_I[i*OUTPUT_DATA_WIDTH +: OUTPUT_DATA_WIDTH] = RAM_I_arr[i];
        end
    endgenerate

    generate
        for (i = 0; i < TWD_POINTS; i = i + 1) begin : MAP_TWIDDLE
            assign tw_real_arr[i] = tw_real[i*INPUT_DATA_WIDTH +: INPUT_DATA_WIDTH];
            assign tw_imag_arr[i] = tw_imag[i*INPUT_DATA_WIDTH +: INPUT_DATA_WIDTH];
        end
    endgenerate

    generate
        for (i = 0; i < BUTTERFLIES; i = i + 1 ) begin: GEN_BF
            butterfly #(
                .DATA_WIDTH(OUTPUT_DATA_WIDTH),
                .TWIDDLE_WIDTH(INPUT_DATA_WIDTH),
                .FRAC_BITS(FRAC_BITS)
            )BF(
                .IN_A_R(IN_bus_A_R[i]),
                .IN_A_I(IN_bus_A_I[i]),
                .IN_B_R(IN_bus_B_R[i]),
                .IN_B_I(IN_bus_B_I[i]),
                .T_R(IN_bus_T_R[i]),
                .T_I(IN_bus_T_I[i]),
                .OUT_A_R(OUT_bus_A_R[i]),
                .OUT_A_I(OUT_bus_A_I[i]),
                .OUT_B_R(OUT_bus_B_R[i]),
                .OUT_B_I(OUT_bus_B_I[i])
            );
        end
    endgenerate


    reg[MAX_STAGES-1:0]K[0:BUTTERFLIES-1];
    localparam C_STATE_WIDTH = MAX_STAGES - BUTTERFLY_FACTOR; // !!
    wire [C_STATE_WIDTH-1:0] c_state;
    assign c_state =
        (input_stage <= (BUTTERFLY_FACTOR + 1)) ?
        0 :
        ((1 << (input_stage - BUTTERFLY_FACTOR - 1)) -1);  

    reg [INPUT_STAGE_WIDTH-1:0]stage;
    reg [C_STATE_WIDTH-1:0]cycle;

    reg [MAX_STAGES-1:0] IN_A_idx [0:BUTTERFLIES-1];
    reg [MAX_STAGES-1:0] IN_B_idx [0:BUTTERFLIES-1];
    reg [MAX_STAGES-2:0] IN_T_idx [0:BUTTERFLIES-1];
    
    
    integer a, j;
    always @(*) begin
        if (stage == 0) begin
            for (a = 0; a < BUTTERFLIES; a = a + 1) begin
                IN_A_idx[a] = ((K[a] >> stage) << (stage + 1)) | (K[a] & ((1 << stage) - 1));
                IN_bus_A_R[a] = {
                    {INPUT_SIGN_EXT_WIDTH{input_mem_arr[IN_A_idx[a]][INPUT_DATA_WIDTH-1]}},
                    input_mem_arr[IN_A_idx[a]]
                };
                IN_bus_A_I[a] = {INPUT_DATA_WIDTH{1'b0}};
                IN_B_idx[a] = IN_A_idx[a] | (1 << stage);
                IN_bus_B_R[a] = {
                    {INPUT_SIGN_EXT_WIDTH{input_mem_arr[IN_B_idx[a]][INPUT_DATA_WIDTH-1]}},
                    input_mem_arr[IN_B_idx[a]]
                };
                IN_bus_B_I[a] = {INPUT_DATA_WIDTH{1'b0}};
                IN_T_idx[a] = 0;
                IN_bus_T_R[a] = tw_real_arr[IN_T_idx[a]];
                IN_bus_T_I[a] = tw_imag_arr[IN_T_idx[a]];
            end

        end
        else begin
            for (a = 0; a < BUTTERFLIES; a = a + 1) begin
                IN_A_idx[a] = ((K[a] >> stage) << (stage + 1)) | (K[a] & ((1 << stage) - 1));
                IN_bus_A_R[a] = RAM_R_arr[IN_A_idx[a]];
                IN_bus_A_I[a] = RAM_I_arr[IN_A_idx[a]];
                IN_B_idx[a] = IN_A_idx[a] | (1 << stage);
                IN_bus_B_R[a] = RAM_R_arr[IN_B_idx[a]];
                IN_bus_B_I[a] = RAM_I_arr[IN_B_idx[a]];
                IN_T_idx[a] = ((K[a] & ((1 << stage) - 1)) << (MAX_STAGES - 1 - stage));
                IN_bus_T_R[a] = tw_real_arr[IN_T_idx[a]];
                IN_bus_T_I[a] = tw_imag_arr[IN_T_idx[a]];
            end
        end
    end
    reg [1:0] state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 2'd0;
            stage <= {INPUT_STAGE_WIDTH{1'b0}};
            cycle <= {C_STATE_WIDTH{1'b0}};
            in_loaded <= 1'b0;
            fft_ready <= 1'b0;
            for (j = 0; j < BUTTERFLIES; j = j +1) begin
                K[j] <= j;
            end
        end
        else begin
            case (state)
                2'd0: begin
                    fft_ready <= 1'b0;
                    if(data_ready)begin
                        for (j = 0; j < BUTTERFLIES; j = j + 1) begin
                            if (input_stage != 0 && (K[j] < (1 << (input_stage - 1)))) begin
                                RAM_R_arr[IN_A_idx[j]] <= OUT_bus_A_R[j];
                                RAM_R_arr[IN_B_idx[j]] <= OUT_bus_B_R[j];
                                
                                RAM_I_arr[IN_A_idx[j]] <= OUT_bus_A_I[j];
                                RAM_I_arr[IN_B_idx[j]] <= OUT_bus_B_I[j];
                            end
                        end
                        if (cycle < c_state) begin
                            cycle <= cycle + 1'b1;
                            for (j = 0; j < BUTTERFLIES; j = j +1) begin
                                K[j] <= K[j] + BUTTERFLIES;
                            end
                        end
                        else begin
                            in_loaded <= 1'b1;
                            cycle <= {C_STATE_WIDTH{1'b0}};
                            for (j = 0; j < BUTTERFLIES; j = j +1) begin
                                K[j] <= j;
                            end
                            if (stage < (input_stage - 1)) begin
                                state <= 2'd1;
                                stage <= stage + 1'b1;
                            end
                            else
                                state <= 2'd2;
                        end
                    end
                end 
                2'd1: begin
                    in_loaded <= 1'b0;
                    for (j = 0; j < BUTTERFLIES; j = j + 1) begin
                        if (input_stage != 0 && (K[j] < (1 << (input_stage - 1)))) begin
                            RAM_R_arr[IN_A_idx[j]] <= OUT_bus_A_R[j];
                            RAM_R_arr[IN_B_idx[j]] <= OUT_bus_B_R[j];
                            
                            RAM_I_arr[IN_A_idx[j]] <= OUT_bus_A_I[j];
                            RAM_I_arr[IN_B_idx[j]] <= OUT_bus_B_I[j];
                        end
                    end
                    if (cycle < c_state) begin
                        cycle <= cycle + 1'b1;
                        for (j = 0; j < BUTTERFLIES; j = j +1) begin
                            K[j] <= K[j] + BUTTERFLIES;
                        end
                    end
                    else begin
                        cycle <= {C_STATE_WIDTH{1'b0}};
                        for (j = 0; j < BUTTERFLIES; j = j +1) begin
                            K[j] <= j;
                        end
                        if (stage < (input_stage-1)) begin
                            state <= 2'd1;
                            stage <= stage + 1'b1;
                        end
                        else
                            state <= 2'd2;
                    end
                end
                2'd2: begin
                    in_loaded <= 1'b0;
                    fft_ready <= 1'b1;
                    if(buff_loaded) begin
                        state <= 2'd0;
                        stage <= 0;
                        cycle <= 0;
                    end
                end
                default: begin
                end
            endcase
        end
    end

endmodule