`timescale 1ns / 1ps

module mini_tetris_top(
    input  wire clk,
    input  wire [11:0] sw, //reset
    input  wire btnU, //rotate
    input  wire btnL, //move left
    input  wire btnR, //move right
    input  wire btnD, //soft drop

    //VGA interface
    output wire [3:0]  vgaRed,
    output wire [3:0]  vgaGreen,
    output wire [3:0]  vgaBlue,
    output wire  hsync,
    output wire  vsync,

    //7-seg interface
    output wire [6:0]  seg,
    output wire [3:0]  an,
    output wire  dp,
    
    output wire audio_out,
    output wire amp_enable
);

    reg  [3:0] score = 0;
    wire       win = (score >= 4'd10);

    mustop music(
        .clk(clk),
        .sw1(sw[1]),
        .wincheck(win),
        .audio_out(audio_out),
        .amp_enable(amp_enable)
    );

    //Board parameters
    localparam COLS     = 10;
    localparam ROWS     = 15;

    localparam COL_BITS = 4;
    localparam ROW_BITS = 4;

    localparam [COL_BITS-1:0] SPAWN_X = COLS/2;  //5

    //Piece types
    localparam [1:0] PIECE_I = 2'd0;
    localparam [1:0] PIECE_S = 2'd1;
    localparam [1:0] PIECE_O = 2'd2;

    wire reset = sw[0];

    //VGA timing
    wire        video_on;
    wire        pixel_tick;
    wire [9:0]  pixel_x;
    wire [9:0]  pixel_y;

    vga_beh vga_unit (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .p_tick(pixel_tick),
        .x(pixel_x),
        .y(pixel_y)
    );

    //Button sync
    reg [1:0] sync_L, sync_R, sync_D, sync_U;

    always @(posedge clk) begin
        sync_L <= {sync_L[0], btnL};
        sync_R <= {sync_R[0], btnR};
        sync_D <= {sync_D[0], btnD};
        sync_U <= {sync_U[0], btnU};
    end

    wire btnL_s = sync_L[1];
    wire btnR_s = sync_R[1];
    wire btnD_s = sync_D[1];
    wire btnU_s = sync_U[1];

    //gravity and button tick
    localparam integer DROP_MAX = 27'd50_000_000;
    reg [26:0] drop_cnt = 0;
    wire       drop_tick = (drop_cnt == DROP_MAX-1);

    always @(posedge clk) begin
        if (reset) begin
            drop_cnt <= 0;
        end else if (drop_tick) begin
            drop_cnt <= 0;
        end else begin
            drop_cnt <= drop_cnt + 1;
        end
    end

    //debouncing
    localparam integer BTN_MAX = 20'd1_000_000;
    reg [19:0] btn_cnt = 0;
    wire       btn_tick = (btn_cnt == BTN_MAX-1);

    always @(posedge clk) begin
        if (reset) begin
            btn_cnt <= 0;
        end else if (btn_tick) begin
            btn_cnt <= 0;
        end else begin
            btn_cnt <= btn_cnt + 1;
        end
    end

    //Debouncers for L/R/U
    reg btnL_db, btnR_db, btnU_db;
    reg btnL_db_prev, btnR_db_prev, btnU_db_prev;

    always @(posedge clk) begin
        if (reset) begin
            btnL_db <= 1'b0;
            btnR_db  <= 1'b0;
            btnU_db  <= 1'b0;
            btnL_db_prev <= 1'b0;
            btnR_db_prev <= 1'b0;
            btnU_db_prev <= 1'b0;
        end else if (btn_tick) begin
            btnL_db_prev <= btnL_db;
            btnR_db_prev <= btnR_db;
            btnU_db_prev <= btnU_db;

            btnL_db <= btnL_s;
            btnR_db <= btnR_s;
            btnU_db <= btnU_s;
        end
    end

    wire btnL_press = btnL_db && ~btnL_db_prev;
    wire btnR_press = btnR_db && ~btnR_db_prev;
    wire btnU_press = btnU_db && ~btnU_db_prev;   //rotate/new game on win

    //Game state
    //Locked board cells
    reg [COLS-1:0] board [0:ROWS-1];

    //Current falling piece
    reg [COL_BITS-1:0] cur_x;
    reg [ROW_BITS-1:0] cur_y;
    reg [1:0] active_type;   //type of current piece
    reg [1:0] next_type;     //which piece to spawn next
    reg [1:0] rotation;      //0-3
    reg piece_active;
    
    //Line clearing state
    reg                clear_pending;  //flag that lines need clearing

    //Score/win
   // reg  [3:0] score = 0;
    //wire       win = (score >= 4'd10);

    integer r, rr;

    //piece geometry and placement

    //4 cell positions given type, rotation, origin
    task get_piece_cells;
        input  [1:0] p_type;
        input  [1:0]  rot;
        input  [COL_BITS-1:0] ox;
        input  [ROW_BITS-1:0] oy;
        output [COL_BITS-1:0] x0, x1, x2, x3;
        output [ROW_BITS-1:0] y0, y1, y2, y3;
    begin
        x0 = ox; y0 = oy;
        x1 = ox; y1 = oy;
        x2 = ox; y2 = oy;
        x3 = ox; y3 = oy;

        case (p_type)
            PIECE_I: begin
                case (rot)
                    2'd0, 2'd2: begin
                        //horizontal
                        x0 = ox - 1; y0 = oy;
                        x1 = ox;     y1 = oy;
                        x2 = ox + 1; y2 = oy;
                        x3 = ox + 2; y3 = oy;
                    end
                    2'd1, 2'd3: begin
                        //vertical
                        x0 = ox; y0 = oy - 1;
                        x1 = ox; y1 = oy;
                        x2 = ox; y2 = oy + 1;
                        x3 = ox; y3 = oy + 2;
                    end
                endcase
            end

            PIECE_S: begin
                case (rot)
                    2'd0, 2'd2: begin
                        //S horizontal
                        //[ox-1,oy] [ox,oy]
                        //[ox,oy+1] [ox+1,oy+1]
                        x0 = ox - 1; y0 = oy;
                        x1 = ox;     y1 = oy;
                        x2 = ox;     y2 = oy + 1;
                        x3 = ox + 1; y3 = oy + 1;
                    end
                    2'd1, 2'd3: begin
                        //S vertical
                        //[ox,oy-1]
                        //[ox-1,oy] [ox,oy]
                        //[ox-1,oy+1]
                        x0 = ox;     y0 = oy - 1;
                        x1 = ox;     y1 = oy;
                        x2 = ox - 1; y2 = oy;
                        x3 = ox - 1; y3 = oy + 1;
                    end
                endcase
            end

            PIECE_O: begin
                //2x2 block, rotation negligable
                x0 = ox;     y0 = oy;
                x1 = ox + 1; y1 = oy;
                x2 = ox;     y2 = oy + 1;
                x3 = ox + 1; y3 = oy + 1;
            end

            default: begin
                x0 = ox; y0 = oy;
                x1 = ox; y1 = oy;
                x2 = ox; y2 = oy;
                x3 = ox; y3 = oy;
            end
        endcase
    end
    endtask

    //check if a single cell is inside board and empty
    task cell_empty;
        input  [COL_BITS-1:0] cx;
        input  [ROW_BITS-1:0] cy;
        output                empty;
    begin
        if (cy >= ROWS || cx >= COLS) begin
            empty = 1'b0; //oob
        end else if (board[cy][cx]) begin
            empty = 1'b0; //occupied
        end else begin
            empty = 1'b1;
        end
    end
    endtask

    //place a full piece at (ox,oy) check
    task can_place;
        input  [1:0]  p_type;
        input  [1:0]  rot;
        input  [COL_BITS-1:0] ox;
        input  [ROW_BITS-1:0] oy;
        output ok;
        reg [COL_BITS-1:0] x0, x1, x2, x3;
        reg [ROW_BITS-1:0] y0, y1, y2, y3;
        reg e0, e1, e2, e3;
    begin
        get_piece_cells(p_type, rot, ox, oy, x0, x1, x2, x3, y0, y1, y2, y3);
        cell_empty(x0, y0, e0);
        cell_empty(x1, y1, e1);
        cell_empty(x2, y2, e2);
        cell_empty(x3, y3, e3);
        ok = e0 & e1 & e2 & e3;
    end
    endtask

    //Lock a piece into board array
    task lock_piece;
        input  [1:0] p_type;
        input  [1:0] rot;
        input  [COL_BITS-1:0] ox;
        input  [ROW_BITS-1:0] oy;
        reg [COL_BITS-1:0] x0, x1, x2, x3;
        reg [ROW_BITS-1:0] y0, y1, y2, y3;
    begin
        get_piece_cells(p_type, rot, ox, oy, x0, x1, x2, x3, y0, y1, y2, y3);

        //assume the piece is valid
        if (y0 < ROWS && x0 < COLS) board[y0][x0] <= 1'b1;
        if (y1 < ROWS && x1 < COLS) board[y1][x1] <= 1'b1;
        if (y2 < ROWS && x2 < COLS) board[y2][x2] <= 1'b1;
        if (y3 < ROWS && x3 < COLS) board[y3][x3] <= 1'b1;
    end
    endtask

    //clear board, line clears, etc.
    task clear_board;
        integer i;
    begin
        for (i = 0; i < ROWS; i = i + 1) begin
            board[i] <= {COLS{1'b0}};
        end
    end
    endtask

    task check_and_clear_lines;
        integer check_row;
        reg [ROWS-1:0] rows_to_clear;
        integer shift_amount;
        integer src_row, dst_row;
    begin
        //identify which rows are full
        rows_to_clear = {ROWS{1'b0}};
        for (check_row = 0; check_row < ROWS; check_row = check_row + 1) begin
            if (board[check_row] == {COLS{1'b1}}) begin
                rows_to_clear[check_row] = 1'b1;
            end
        end
        
        //compact the board by removing full rows
        //bottom to top
        dst_row = ROWS - 1;
        for (src_row = ROWS - 1; src_row > 0; src_row = src_row - 1) begin
            if (!rows_to_clear[src_row]) begin
                if (dst_row != src_row) begin
                    board[dst_row] <= board[src_row];
                end
                dst_row = dst_row - 1;
            end
        end
        //row 0 separately
        if (!rows_to_clear[0]) begin
            if (dst_row != 0) begin
                board[dst_row] <= board[0];
            end
            dst_row = dst_row - 1;
        end
        
        //Fill top rows with empty rows
        for (check_row = 0; check_row <= dst_row && check_row < ROWS; check_row = check_row + 1) begin
            board[check_row] <= {COLS{1'b0}};
        end
        
        //Count lines cleared and update score
        shift_amount = 0;
        for (check_row = 0; check_row < ROWS; check_row = check_row + 1) begin
            if (rows_to_clear[check_row])
                shift_amount = shift_amount + 1;
        end
        
        if (score + shift_amount > 4'd10)
            score <= 4'd10;
        else
            score <= score + shift_amount;
    end
    endtask

    //Game logic
    reg spawn_ok;
    reg can_down;
    reg rot_ok;
    reg [1:0] new_rot;

    always @(posedge clk) begin
        if (reset) begin
            clear_board();
            cur_x  <= SPAWN_X;
            cur_y  <= 0;
            piece_active <= 1'b0;
            clear_pending <= 1'b0;
            score <= 4'd0;
            active_type <= PIECE_I;
            next_type <= PIECE_S;
            rotation <= 2'd0;
        end else begin
            //btnU_press starts a new game
            if (win && btnU_press) begin
                clear_board();
                cur_x  <= SPAWN_X;
                cur_y <= 0;
                piece_active <= 1'b0;
                clear_pending <= 1'b0;
                score  <= 4'd0;
                active_type  <= PIECE_I;
                next_type <= PIECE_S;
                rotation <= 2'd0;
            end

            //Line clearing happens immediately when pending
            if (clear_pending) begin
                check_and_clear_lines();
                clear_pending <= 1'b0;
            end

            //auto drop logic
            if (drop_tick && !win && !clear_pending) begin
                if (!piece_active) begin
                    //Try to spawn next_type at top-center, rot=0
                    can_place(next_type, 2'd0, SPAWN_X, 0, spawn_ok);
                    if (!spawn_ok) begin
                        //cannot spawn, reset board + score
                        clear_board();
                        score <= 4'd0;
                        cur_x  <= SPAWN_X;
                        cur_y <= 0;
                        piece_active <= 1'b0;
                        clear_pending <= 1'b0;
                        rotation  <= 2'd0;
                        active_type  <= PIECE_I;
                        next_type  <= PIECE_S;
                    end else begin
                        active_type  <= next_type;
                        cur_x  <= SPAWN_X;
                        cur_y <= 0;
                        rotation<= 2'd0;
                        piece_active <= 1'b1;

                        //Cycle next_type
                        case (next_type)
                            PIECE_I: next_type <= PIECE_S;
                            PIECE_S: next_type <= PIECE_O;
                            PIECE_O: next_type <= PIECE_I;
                            default: next_type <= PIECE_I;
                        endcase
                    end
                end else begin
                    //try to fall one row
                    can_place(active_type, rotation, cur_x, cur_y + 1'b1, can_down);
                    if (!can_down) begin
                        //lock
                        lock_piece(active_type, rotation, cur_x, cur_y);
                        piece_active <= 1'b0;
                        clear_pending <= 1'b1;
                    end else begin
                        cur_y <= cur_y + 1'b1;
                    end
                end
            end

            //movement and rotation
            if (btn_tick && piece_active && !win && !clear_pending) begin
                //Left/right
                if (btnL_press) begin
                    can_place(active_type, rotation, cur_x - 1'b1, cur_y, spawn_ok);
                    if (spawn_ok)
                        cur_x <= cur_x - 1'b1;
                end else if (btnR_press) begin
                    can_place(active_type, rotation, cur_x + 1'b1, cur_y, spawn_ok);
                    if (spawn_ok)
                        cur_x <= cur_x + 1'b1;
                end

                //Rotation
                if (btnU_press) begin
                    new_rot = rotation + 2'd1;
                    can_place(active_type, new_rot, cur_x, cur_y, rot_ok);
                    if (rot_ok)
                        rotation <= new_rot;
                end

                //Soft drop
                if (btnD_s) begin
                    can_place(active_type, rotation, cur_x, cur_y + 1'b1, can_down);
                    if (!can_down) begin
                        lock_piece(active_type, rotation, cur_x, cur_y);
                        piece_active <= 1'b0;
                        clear_pending <= 1'b1;
                    end else begin
                        cur_y <= cur_y + 1'b1;
                    end
                end
            end
        end
    end

    //VGA
    reg [3:0] red_reg, green_reg, blue_reg;

    //pixel to board cell
    wire [COL_BITS-1:0] board_col = pixel_x[9:6];  //640/10 = 64
    wire [ROW_BITS-1:0] board_row = pixel_y[9:5];  //480/15 = 32

    wire inside_board = (board_col < COLS) && (board_row < ROWS);
    wire grid_line    = (pixel_x[5:0] == 6'd0) || (pixel_y[4:0] == 5'd0);

    //Prefire active piece cells
    reg [COL_BITS-1:0] px0, px1, px2, px3;
    reg [ROW_BITS-1:0] py0, py1, py2, py3;

    always @* begin
        //default unreachable
        px0 = 0; py0 = 0;
        px1 = 0; py1 = 0;
        px2 = 0; py2 = 0;
        px3 = 0; py3 = 0;

        if (piece_active) begin
            get_piece_cells(active_type, rotation, cur_x, cur_y,
                            px0, px1, px2, px3,
                            py0, py1, py2, py3);
        end
    end

    wire active_here =
        piece_active &&
        ((board_col == px0 && board_row == py0) ||
         (board_col == px1 && board_row == py1) ||
         (board_col == px2 && board_row == py2) ||
         (board_col == px3 && board_row == py3));

    //WIN text rendering
    //text probably in center of screen
    wire [9:0] text_x = pixel_x - 10'd232;
    wire [9:0] text_y = pixel_y - 10'd216;
    wire in_text_region = (pixel_x >= 10'd232) && (pixel_x < 10'd424) && 
                          (pixel_y >= 10'd216) && (pixel_y < 10'd264);
    
    //5 blocks wide 6 blocks tall 8 pixels per
    wire [2:0] char_x = text_x[5:3];
    wire [2:0] char_y = text_y[5:3];
    wire [2:0] char_idx = text_x[7:6];
    
    reg letter_pixel;
    
    always @* begin
        letter_pixel = 1'b0;
        
        if (char_y < 3'd6 && char_x < 3'd5) begin
            case (char_idx)
                // W
                3'd0: begin
                    case (char_y)
                        3'd0: letter_pixel = (char_x == 3'd0 || char_x == 3'd4);
                        3'd1: letter_pixel = (char_x == 3'd0 || char_x == 3'd4);
                        3'd2: letter_pixel = (char_x == 3'd0 || char_x == 3'd4);
                        3'd3: letter_pixel = (char_x == 3'd0 || char_x == 3'd2 || char_x == 3'd4);
                        3'd4: letter_pixel = (char_x == 3'd0 || char_x == 3'd2 || char_x == 3'd4);
                        3'd5: letter_pixel = (char_x == 3'd1 || char_x == 3'd3);
                    endcase
                end
                // I
                3'd1: begin
                    case (char_y)
                        3'd0: letter_pixel = (char_x > 3'd0 && char_x < 3'd4);
                        3'd1: letter_pixel = (char_x == 3'd2);
                        3'd2: letter_pixel = (char_x == 3'd2);
                        3'd3: letter_pixel = (char_x == 3'd2);
                        3'd4: letter_pixel = (char_x == 3'd2);
                        3'd5: letter_pixel = (char_x > 3'd0 && char_x < 3'd4);
                    endcase
                end
                // N
                3'd2: begin
                    case (char_y)
                        3'd0: letter_pixel = (char_x == 3'd0 || char_x == 3'd4);
                        3'd1: letter_pixel = (char_x == 3'd0 || char_x == 3'd1 || char_x == 3'd4);
                        3'd2: letter_pixel = (char_x == 3'd0 || char_x == 3'd2 || char_x == 3'd4);
                        3'd3: letter_pixel = (char_x == 3'd0 || char_x == 3'd3 || char_x == 3'd4);
                        3'd4: letter_pixel = (char_x == 3'd0 || char_x == 3'd4);
                        3'd5: letter_pixel = (char_x == 3'd0 || char_x == 3'd4);
                    endcase
                end
                default: letter_pixel = 1'b0;
            endcase
        end
    end

    always @* begin
        red_reg   = 4'h0;
        green_reg = 4'h0;
        blue_reg  = 4'h0;

        if (video_on) begin
            if (inside_board) begin
                if (win) begin
                    //Win screen
                    if (in_text_region && letter_pixel) begin
                        //White
                        red_reg   = 4'hF;
                        green_reg = 4'hF;
                        blue_reg  = 4'hF;
                    end else begin
                        //Purple
                        red_reg   = 4'h8;
                        green_reg = 4'h0;
                        blue_reg  = 4'h8;
                    end
                end else begin
                    //Background grid
                    if (grid_line) begin
                        red_reg   = 4'h2;
                        green_reg  = 4'h2;
                        blue_reg  = 4'h2;
                    end

                    //Locked cells: green
                    if (board[board_row][board_col]) begin
                        red_reg   = 4'h0;
                        green_reg = 4'hF;
                        blue_reg  = 4'h0;
                    end

                    //Active piece cells: blue
                    if (active_here) begin
                        red_reg   = 4'h0;
                        green_reg = 4'h0;
                        blue_reg  = 4'hF;
                    end
                end
            end else begin
                //Outside board: dark gray
                red_reg   = 4'h1;
                green_reg = 4'h1;
                blue_reg  = 4'h1;
            end
        end
    end

    assign vgaRed   = red_reg;
    assign vgaGreen = green_reg;
    assign vgaBlue  = blue_reg;

    //7-seg score display
    wire [3:0] score_ones = (score > 4'd9) ? (score - 4'd10) : score;
    wire [3:0] score_tens = (score > 4'd9) ? 4'd1 : 4'd0;

    wire [15:0] seg_value = {4'hF, 4'hF, score_tens, score_ones};

    seven_seg_mux seg_unit (
        .clk(clk),
        .reset(reset),
        .value(seg_value),
        .seg(seg),
        .an(an),
        .dp(dp)
    );

endmodule