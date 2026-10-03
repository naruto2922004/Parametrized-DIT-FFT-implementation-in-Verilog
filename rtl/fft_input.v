module fft_input #(
    parameter MAX_STAGES = 10,
    parameter  MAX_POINTS = 1 << (MAX_STAGES),
    parameter INPUT_STAGE_WIDTH = 4, // ceil(log2(MAX_STAGES))
    parameter INPUT_DATA_WIDTH = 16
) (
    input clk, rst_n, data_valid,
    input [INPUT_STAGE_WIDTH-1:0]input_stage,
    input signed[INPUT_DATA_WIDTH-1:0]data_in,
    input in_loaded,
    output reg [INPUT_DATA_WIDTH*MAX_POINTS-1:0]input_mem,
    output reg in_ready, data_ready 
);

    reg state;
    reg [MAX_STAGES-1:0]byte_count; 
    reg [MAX_STAGES-1:0]byte_idx;
    wire [MAX_STAGES-1:0]max_byte;
    assign max_byte = (1 << input_stage) - 1'b1;  

    integer i;
    always @(*) begin
        for (i = 0; i < MAX_STAGES; i = i +1) begin
            if(i < input_stage)
                byte_idx[i] = byte_count[input_stage-1-i];
            else
                byte_idx[i] = 1'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            state <= 1'b0;
            byte_count <= 0;
            in_ready <= 1'b0;
            data_ready <= 1'b0;
        end
        else begin
            if(!state)begin
                in_ready <= 1'b1;
                data_ready <= 1'b0;
                if(data_valid)begin
                    input_mem[byte_idx*INPUT_DATA_WIDTH+: INPUT_DATA_WIDTH] <= data_in;
                    byte_count <= byte_count + 1'b1;
                    if(byte_count >= (max_byte))
                        state <= 1'b1;
                end
            end
            else begin
                in_ready <= 1'b0;
                data_ready <= 1'b1;
                byte_count <= 0;
                if (in_loaded) begin
                    state <= 1'b0;
                end
            end
        end
    end
    
endmodule