`timescale 1ns / 1ps

module pzc_tb;
    parameter nbits = 12;
    parameter nbits_out = 28;
    parameter nsize = 1603800;
    
    // Inputs
    reg clk = 0;
    reg rst = 0;
    reg [nbits-1:0] mem_data [0:nsize-1];
    reg [nbits-1:0] mem_bt [0:nsize-1];
    
    reg signed [nbits-1:0] x;
    reg bt_mask;
    
    // Outputs
    wire signed [nbits-1:0]     pedestal;
    wire signed [13-1:0]        pedestal_13b;
    wire signed [nbits_out-1:0] pzc_out;
    wire signed [13-1:0]        pzc_out_13b;
    
    integer i = 0;
    integer fout_pzc;
    integer fout_ped;
    integer fout_pzc_13b;
    integer fout_ped_13b;
    
    always #5 clk = ~clk;   // clock de 100 MHz

    initial begin
        $readmemh("C:/Users/tmdb/Documents/fabio/doc/PZC_real_data/data/hg_extended.hex", mem_data);
        $readmemh("C:/Users/tmdb/Documents/fabio/doc/PZC_real_data/data/bt_mask.hex", mem_bt);
        
        fout_pzc = $fopen("C:/Users/tmdb/Documents/fabio/doc/PZC_real_data/data/pzc_out.txt", "w");
        fout_ped = $fopen("C:/Users/tmdb/Documents/fabio/doc/PZC_real_data/data/ped_out.txt", "w");
        
        fout_pzc_13b = $fopen("C:/Users/tmdb/Documents/fabio/doc/PZC_real_data/data/pzc13b_out.txt", "w");
        fout_ped_13b = $fopen("C:/Users/tmdb/Documents/fabio/doc/PZC_real_data/data/ped13b_out.txt", "w");
        
        rst = 1;
        #20;        // segura reset por 2 ciclos
        rst = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            i       <= 0;
            x       <= 0;
            bt_mask <= 0;
        end else if (i < nsize) begin
            x       <= mem_data[i];
            bt_mask <= mem_bt[i];
            i       <= i + 1;

            // Grava a saída a cada amostra
            $fdisplay(fout_pzc , "%0d", pzc_out);   
            $fdisplay(fout_ped, "%0d" , pedestal);
            
            $fdisplay(fout_pzc_13b, "%0d", pzc_out_13b);
            $fdisplay(fout_ped_13b, "%0d", pedestal_13b);
        end else begin
            $fclose(fout_pzc);                
            $fclose(fout_ped);
            
            $fclose(fout_pzc_13b);  
            $fclose(fout_ped_13b);  
            $finish;
        end
    end
    
    // Applying PZC full
    pzc_ped_track 
    #(
        .NBITS_OUT(nbits_out),
        .SHIFT_PZC(0)
    )
    pzc (
        .clk        (clk),
        .rst        (rst),
        .bt_mask_out(bt_mask),
        .in         (x),
        .pedestal   (pedestal),
        .pzc_out    (pzc_out)
    );
    
        // Applying PZC full
    pzc_ped_track 
    #(
        .NBITS_OUT(13),
        .SHIFT_PZC(9)
    )
    pzc13b (
        .clk        (clk),
        .rst        (rst),
        .bt_mask_out(bt_mask),
        .in         (x),
        .pedestal   (pedestal_13b),
        .pzc_out    (pzc_out_13b)
    );
endmodule