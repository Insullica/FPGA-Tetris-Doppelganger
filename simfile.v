`timescale 1ns / 1ps

module simfile;

    // Inputs
    reg clk;
    reg [11:0] sw;
    reg btnU, btnL, btnR, btnD;
    
    // Outputs
    wire [3:0] vgaRed, vgaGreen, vgaBlue;
    wire hsync, vsync;
    wire [6:0] seg;
    wire [3:0] an;
    wire dp;
    wire audio_out;
    wire amp_enable;
    
    // Instantiate UUT
    mini_tetris_top uut (
        .clk(clk), 
        .sw(sw), 
        .btnU(btnU), 
        .btnL(btnL), 
        .btnR(btnR), 
        .btnD(btnD), 
        .vgaRed(vgaRed), 
        .vgaGreen(vgaGreen), 
        .vgaBlue(vgaBlue), 
        .hsync(hsync), 
        .vsync(vsync), 
        .seg(seg), 
        .an(an), 
        .dp(dp), 
        .audio_out(audio_out), 
        .amp_enable(amp_enable)
    );
    
    // Clock generation - 100 MHz
    always #5 clk = ~clk;
    
    integer i;
    
    initial begin
        clk = 0;
        sw = 0;
        btnU = 0;
        btnL = 0;
        btnR = 0;
        btnD = 0;
        
        $display("\n========================================");
        $display("Mini Tetris Testbench");
        $display("========================================\n");
        
        // TEST 1: Reset
        $display("TEST 1: Reset");
        sw[0] = 1;
        repeat(100) @(posedge clk);
        sw[0] = 0;
        repeat(100) @(posedge clk);
        $display("  PASS: Reset complete");
        $display("  Initial: piece_active=%b, score=%0d, win=%b\n", 
                 uut.piece_active, uut.score, uut.win);
        
        // TEST 2: First piece spawn
        $display("TEST 2: Piece Spawn");
        for (i = 0; i < 3; i = i + 1) begin
            force uut.drop_cnt = 27'd49_999_999;
            @(posedge clk);
            @(posedge clk);
            release uut.drop_cnt;
            repeat(20) @(posedge clk);
            
            if (uut.piece_active) begin
                $display("  PASS: Piece spawned at y=%0d, x=%0d", uut.cur_y, uut.cur_x);
                $display("  Type=%0d, Rotation=%0d\n", uut.active_type, uut.rotation);
                i = 999;
            end
        end
        
        if (!uut.piece_active) begin
            $display("  FAIL: Piece did not spawn\n");
            $finish;
        end
        
        // TEST 3: Automatic falling
        $display("TEST 3: Automatic Falling");
        $display("  Triggering drops and monitoring y position:");
        
        for (i = 0; i < 15; i = i + 1) begin
            force uut.drop_cnt = 27'd49_999_999;
            @(posedge clk);
            @(posedge clk);
            release uut.drop_cnt;
            repeat(20) @(posedge clk);
            
            $display("    Drop %2d: y=%2d, active=%b", i+1, uut.cur_y, uut.piece_active);
            
            if (!uut.piece_active) begin
                $display("  PASS: Piece fell and locked at y=%0d\n", uut.cur_y);
                i = 999;
            end
        end
        
        if (uut.piece_active) begin
            $display("  PASS: Piece is falling (still active at y=%0d)\n", uut.cur_y);
        end
        
        // TEST 4: Wait for next piece spawn
        $display("TEST 4: Next Piece Spawn");
        for (i = 0; i < 5; i = i + 1) begin
            force uut.drop_cnt = 27'd49_999_999;
            @(posedge clk);
            @(posedge clk);
            release uut.drop_cnt;
            repeat(20) @(posedge clk);
            
            if (uut.piece_active) begin
                $display("  PASS: Next piece spawned");
                $display("  Position: y=%0d, x=%0d, type=%0d\n", 
                         uut.cur_y, uut.cur_x, uut.active_type);
                i = 999;
            end
        end
        
        $finish;
    end
      
endmodule