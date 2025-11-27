`timescale 1ns / 1ps
module mustop(
    input wire clk,
    input wire sw1, 
    input wire wincheck,         
    output wire audio_out, 
    output wire led0,
    output wire led1,
    output wire amp_enable
);
    //Clock divider for audio sample rate (~48 kHz)
    reg [10:0] clk_div = 0;
    wire sample_clk;
    
    //assign amp_enable = 1'b1;
    
    assign amp_enable = (wincheck) ? 1'b0 : 1'b1;
    
    always @(posedge clk) begin
        clk_div <= clk_div + 1;
    end
    assign sample_clk = clk_div[10]; //~48.8 kHz
    
    wire [11:0] sample;
    wire [11:0] gated_sample;
    wire [31:0] note_phase_inc;
    wire note_gate;
    
    //Sequencer controls which note to play
    note_sequencer seq (
        .clk(clk),
        .enable(sw1),
        .phase_inc(note_phase_inc),
        .note_gate(note_gate)
    );
    
    //Generate the tone at audio sample rate
    tone_gen tg (
        .clk(sample_clk),
        .phase_inc(note_phase_inc),
        .sample(sample)
    );
    
    //Gate the sample based on SW1 and note_gate
    assign gated_sample = (sw1 && note_gate) ? sample : 12'd2048;
    assign led0 = sw1;
    assign led1 = audio_out;
    
    //Output via PWM DAC at high frequency
    pwm_dac #(.BITS(12)) dac (
        .clk(clk),
        .sample(gated_sample),
        .pwm_out(audio_out)
    );
endmodule

module note_sequencer(
    input  wire clk,
    input  wire enable,
    output reg [31:0] phase_inc,
    output reg note_gate
);
    //Note frequencies (phase increments for 48.8 kHz sample rate)
   // localparam A3  = 32'd19316764;  // 220.00 Hz
   // localparam B3  = 32'd21683069;  // 246.94 Hz
    localparam C5  = 32'd46025675;  // 523.25 Hz
    localparam D5  = 32'd51662225;  // 587.33 Hz
    localparam E5  = 32'd57988392;  // 659.25 Hz
    localparam F5  = 32'd61437349;  // 698.46 Hz
    localparam G5  = 32'd68960666;  // 783.99 Hz
    localparam A4  = 32'd38702908;  // 440.00 Hz
    localparam A5  = 32'd77405817;  // 880.00 Hz
    localparam B4  = 32'd43442255;  // 493.88 Hz
    
    
    //Duration units
    localparam EIGHTH = 28'd12500000;   // 0.125 seconds
    localparam QUARTER = 28'd25000000;  // 0.25 seconds
    localparam HALF = 28'd50000000;     // 0.5 seconds
    localparam WHOLE = 28'd100000000;   // 1.0 second
    
    //Pause units
    localparam SHORT_PAUSE = 28'd2500000;  // 25ms
    localparam LONG_PAUSE = 28'd5000000;   // 50ms
    localparam LONGER_PAUSE = 28'd25000000;   // 250ms
    
    localparam NUM_NOTES = 37;
    
    reg [31:0] notes [0:NUM_NOTES-1];
    reg [27:0] durations [0:NUM_NOTES-1];
    reg [27:0] pauses [0:NUM_NOTES-1];
    
    initial begin
        //Tetris theme hopefully
        notes[0]  = E5;  durations[0]  = HALF;  pauses[0]  = SHORT_PAUSE;
        notes[1]  = B4;  durations[1]  = QUARTER;  pauses[1]  = SHORT_PAUSE;
        notes[2]  = C5;  durations[2]  = QUARTER;  pauses[2]  = SHORT_PAUSE;
        notes[3]  = D5;  durations[3]  = HALF;  pauses[3]  = SHORT_PAUSE;
        notes[4]  = C5;  durations[4]  = QUARTER;  pauses[4]  = SHORT_PAUSE;
        notes[5]  = B4;  durations[5]  = QUARTER;  pauses[5]  = SHORT_PAUSE;
        notes[6]  = A4;  durations[6]  = HALF;     pauses[6]  = SHORT_PAUSE;
        notes[7]  = A4;  durations[7]  = QUARTER;  pauses[7]  = SHORT_PAUSE;
        notes[8]  = C5;  durations[8]  = QUARTER;  pauses[8]  = SHORT_PAUSE;
        notes[9]  = E5;  durations[9]  = HALF;  pauses[9]  = SHORT_PAUSE;
        notes[10] = D5;  durations[10] = QUARTER;  pauses[10] = SHORT_PAUSE;
        notes[11] = C5;  durations[11] = QUARTER;  pauses[11] = SHORT_PAUSE;
        notes[12] = B4;  durations[12] = HALF;  pauses[12] = LONG_PAUSE;
        notes[13] = C5;  durations[13] = QUARTER;     pauses[13] = SHORT_PAUSE;
        notes[14] = D5;  durations[14] = HALF;     pauses[14] = SHORT_PAUSE;
        notes[15] = E5;  durations[15] = HALF;     pauses[15] = SHORT_PAUSE;
        notes[16] = C5;  durations[16] = HALF;     pauses[16] = SHORT_PAUSE;
        notes[17] = A4;  durations[17] = HALF;     pauses[17] = LONG_PAUSE;
        notes[18] = A4;  durations[18] = WHOLE;     pauses[18] = LONGER_PAUSE;
        
        notes[19] = D5;  durations[19] = HALF;     pauses[19] = SHORT_PAUSE;
        notes[20] = F5;  durations[20] = QUARTER;     pauses[20] = SHORT_PAUSE;
        notes[21] = A5;  durations[21] = HALF;     pauses[21] = SHORT_PAUSE;
        notes[22] = G5;  durations[22] = QUARTER;     pauses[22] = SHORT_PAUSE;
        notes[23] = F5;  durations[23] = QUARTER;     pauses[23] = SHORT_PAUSE;
        notes[24] = E5;  durations[24] = HALF;     pauses[24] = LONG_PAUSE;
        notes[25] = C5;  durations[25] = QUARTER;     pauses[25] = SHORT_PAUSE;
        notes[26] = E5;  durations[26] = HALF;     pauses[26] = SHORT_PAUSE;
        notes[27] = D5;  durations[27] = QUARTER;     pauses[27] = SHORT_PAUSE;
        notes[28] = C5;  durations[28] = QUARTER;     pauses[28] = SHORT_PAUSE;
        notes[29] = B4;  durations[29] = HALF;     pauses[29] = LONG_PAUSE;
        notes[30] = B4;  durations[30] = QUARTER;     pauses[30] = SHORT_PAUSE;
        notes[31] = C5;  durations[31] = QUARTER;     pauses[31] = SHORT_PAUSE;
        notes[32] = D5;  durations[32] = HALF;     pauses[32] = SHORT_PAUSE;
        notes[33] = E5;  durations[33] = HALF;     pauses[33] = SHORT_PAUSE;
        notes[34] = C5;  durations[34] = HALF;     pauses[34] = SHORT_PAUSE;
        notes[35] = A4;  durations[35] = HALF;     pauses[35] = LONG_PAUSE;
        notes[36] = A4;  durations[36] = WHOLE;     pauses[36] = LONGER_PAUSE;
        
        
        
    end
    
    reg [6:0] note_index = 0;
    reg [27:0] note_timer = 0;
    wire [27:0] current_duration;
    wire [27:0] current_pause;
    
    assign current_duration = durations[note_index];
    assign current_pause = pauses[note_index];
    
    always @(posedge clk) begin
        if (!enable) begin
            note_index <= 0;
            note_timer <= 0;
            phase_inc <= C5;
            note_gate <= 1'b0;
        end else begin
            note_timer <= note_timer + 1;
            
            //Note plays for (duration - pause), then silence for pause
            if (note_timer < (current_duration - current_pause)) begin
                note_gate <= 1'b1;  //Play note
            end else begin
                note_gate <= 1'b0;  //Pause
            end
            
            if (note_timer >= current_duration) begin
                note_timer <= 0;
                
                if (note_index < NUM_NOTES - 1)
                    note_index <= note_index + 1;
                else
                    note_index <= 0; //Loop back to start
            end
            
            phase_inc <= notes[note_index];
        end
    end
endmodule

module pwm_dac #(
    parameter BITS = 12
)(
    input  wire clk,             
    input  wire [BITS-1:0] sample,
    output reg pwm_out
);
    reg [BITS-1:0] counter = 0;
    
    always @(posedge clk) begin
        counter <= counter + 1;
        pwm_out <= (counter < sample);
    end
endmodule

module tone_gen(
    input  wire clk,
    input  wire [31:0] phase_inc,
    output reg [11:0] sample
);
    reg [31:0] phase = 0;
    
    always @(posedge clk) begin
        phase <= phase + phase_inc;
        sample <= phase[31:20];
    end
endmodule