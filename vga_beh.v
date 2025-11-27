`timescale 1ns / 1ps

module vga_beh(
    input  wire clk,
    input  wire reset,
    output wire hsync,
    output wire vsync,
    output wire video_on,
    output wire p_tick, //pixel tick 25 MHz enable
    output wire [9:0] x,
    output wire [9:0] y
);
    //25 MHz pixel tick from 100 MHz
    reg [1:0] pix_cnt = 0;
    reg p_tick_reg = 0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pix_cnt <= 0;
            p_tick_reg <= 0;
        end else begin
            pix_cnt <= pix_cnt + 1'b1;
            if (pix_cnt == 2'b11) begin
                p_tick_reg <= 1'b1;
            end else begin
                p_tick_reg <= 1'b0;
            end
        end
    end

    assign p_tick = p_tick_reg;

    //VGA timing constants
    localparam H_DISPLAY = 640;
    localparam H_FP    = 16;
    localparam H_SYNC  = 96;
    localparam H_BP   = 48;
    localparam H_MAX   = H_DISPLAY + H_FP + H_SYNC + H_BP - 1; //799

    localparam V_DISPLAY = 480;
    localparam V_FP   = 10;
    localparam V_SYNC  = 2;
    localparam V_BP  = 33;
    localparam V_MAX  = V_DISPLAY + V_FP + V_SYNC + V_BP - 1; //524

    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    //Horizontal/ vertical counters
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end else if (p_tick) begin
            if (h_count == H_MAX) begin
                h_count <= 0;
                if (v_count == V_MAX)
                    v_count <= 0;
                else
                    v_count <= v_count + 1'b1;
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    //Sync pulses active low
    assign hsync = ~((h_count >= (H_DISPLAY + H_FP)) &&
                     (h_count <  (H_DISPLAY + H_FP + H_SYNC)));

    assign vsync = ~((v_count >= (V_DISPLAY + V_FP)) &&
                     (v_count <  (V_DISPLAY + V_FP + V_SYNC)));

    //Video on when within visible area
    assign video_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);

    //Current pixel position
    assign x = h_count;
    assign y = v_count;

endmodule
