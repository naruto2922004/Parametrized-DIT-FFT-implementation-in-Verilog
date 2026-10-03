module fft_output #(
    parameter MAX_STAGES = 10,
    parameter  MAX_POINTS = 1 << (MAX_STAGES),
    parameter OUTPUT_DATA_WIDTH = 32
) (
    input clk, rst_n, read_next, read_done, fft_ready,
    input signed[OUTPUT_DATA_WIDTH*MAX_POINTS-1:0]IN_RAM_R, IN_RAM_I,
    output signed[OUTPUT_DATA_WIDTH-1:0] output_data_R, output_data_I,
    output reg buff_loaded, output_ready
);
    reg [OUTPUT_DATA_WIDTH-1:0]RAM_R[0:MAX_POINTS-1];
    reg [OUTPUT_DATA_WIDTH-1:0]RAM_I[0:MAX_POINTS-1];
    reg [MAX_STAGES-1:0]out_pointer;
    reg state;

    assign output_data_R = (state) ? RAM_R[out_pointer] : {OUTPUT_DATA_WIDTH{1'b0}};
    assign output_data_I = (state) ? RAM_I[out_pointer] : {OUTPUT_DATA_WIDTH{1'b0}};

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_pointer <= 0;
            state <= 1'b0;
            buff_loaded <= 1'b0;
            output_ready <= 1'b0;
        end
        else begin
            if (fft_ready && !buff_loaded) begin
                // New FFT frame arrived: load and override buffer immediately
                out_pointer <= 0; 
                state <= 1'b1;
                buff_loaded <= 1'b1;
                output_ready <= 1'b1;
                for (i = 0; i < MAX_POINTS; i = i + 1) begin
                    RAM_R[i] <= IN_RAM_R[i*OUTPUT_DATA_WIDTH+:OUTPUT_DATA_WIDTH];
                    RAM_I[i] <= IN_RAM_I[i*OUTPUT_DATA_WIDTH+:OUTPUT_DATA_WIDTH];
                end
            end
            else begin
                if (!fft_ready)
                    buff_loaded <= 1'b0;

                if (state) begin
                    if (read_done) begin
                        out_pointer <= 0; 
                        state <= 1'b0;
                        output_ready <= 1'b0;
                    end
                    else if (read_next) begin
                        out_pointer <= out_pointer + 1'b1;
                    end
                end
            end
        end
    end

endmodule