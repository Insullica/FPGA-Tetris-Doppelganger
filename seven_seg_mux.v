`timescale 1ns / 1ps

module seven_seg_mux(
    input  wire clk,
    input  wire reset,
    input  wire [15:0] value,
    output reg [6:0] seg,
    output reg [3:0] an,
    output reg dp
);
    reg [1:0]  digit_sel;
    reg [3:0]  curr_digit;
    reg [15:0] refresh_cnt;

    //Refresh counter to cycle through
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            refresh_cnt <= 16'd0;
        end else begin
            refresh_cnt <= refresh_cnt + 1'b1;
        end
    end

    //Use top two bits to select the digit
    always @* begin
        digit_sel = refresh_cnt[15:14];
        case (digit_sel)
            2'b00: begin
                an  = 4'b1110;   //rightmost digit on
                curr_digit = value[3:0];
            end
            2'b01: begin
                an  = 4'b1101;
                curr_digit = value[7:4];
            end
            2'b10: begin
                an  = 4'b1011;
                curr_digit = value[11:8];
            end
            2'b11: begin
                an = 4'b0111;   //leftmost digit
                curr_digit = value[15:12];
            end
        endcase
    end

    // BCD to 7-seg decoder (active LOW)
    always @* begin
        case (curr_digit)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            4'hF: seg = 7'b1111111;//blank
            default: seg = 7'b1111111;
        endcase
    end

    //Decimal point off
    always @* begin
        dp = 1'b1;
    end

endmodule
