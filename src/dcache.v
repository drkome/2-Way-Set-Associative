module dcache (

        input                       clk_i         ,
        input                       reset_i       ,
        
        input                       stall_i       ,
        input       [3:0]           wstrb_i       ,
        input                       write_en      ,
        input                       read_en       ,
        input       [31:0]          adress_i      ,
        input       [31:0]          data_i        ,
        output      [31:0]          data_o        ,
        output                      lsu_stall_o   ,
        input                       veriyolu_aktif,


        output  reg                 iomem_valid   ,
        input                       iomem_ready   ,
        output  reg     [3:0]       iomem_wstrb   ,
        (* dont_touch = "yes" *)output  reg     [31:0]      iomem_addr    ,
        output  reg     [31:0]      iomem_wdata   ,
        input           [31:0]      iomem_rdata      

);

// CACHE ISLEMLERI ICIN
localparam HIT         =   3'b000 ;
localparam HAFIZA_CEK  =   3'b001 ;
localparam HAFIZA_YAZ  =   3'b011 ;
localparam BITTI       =   3'b111 ;

// CACHE BOSALTMAK ICIN
localparam BOSTA         =   2'b00 ;
localparam SIL           =   2'b01 ;
localparam SILME_BITTI   =   2'b10 ;


reg     [7:0]   counter         =    0;
reg     [2:0]   state           =    HIT;
reg     [1:0]   state_bosaltma  =    BOSTA;
(* dont_touch = "yes" *)reg     [31:0]  adress_next;
reg     [7:0]   adress;

reg             bosaltma_aktif  ;
reg     [31:0]  data_next       ;
reg             hit0            ;
reg             hit1            ;



reg   [3:0]     write0          ;
reg   [3:0]     write1          ;
reg             read0           ;
reg             read1           ;



wire   [7:0]   data00_o        ;      
wire   [7:0]   data01_o        ;      
wire   [7:0]   data02_o        ;      
wire   [7:0]   data03_o        ;      

wire   [7:0]   data10_o        ;      
wire   [7:0]   data11_o        ;      
wire   [7:0]   data12_o        ;      
wire   [7:0]   data13_o        ;      



reg             stall           ;

reg    [3:0]    write_next;



reg  [21:0]     tag0    [0:255];
reg  [1:0]      lru0    [0:255];
reg             onay0   [0:255];
reg             dirty0  [0:255];


reg  [21:0]     tag1    [0:255];
reg  [1:0]      lru1    [0:255];
reg             onay1   [0:255];
reg             dirty1  [0:255];



assign lsu_stall_o  = stall;



assign  data_o = (read0)? {data03_o,data02_o,data01_o,data00_o} :
                 (read1)? {data13_o,data12_o,data11_o,data10_o} :32'b0;




always @(posedge clk_i) begin

    if(!reset_i ||  bosaltma_aktif)begin
        stall           <=  0;
        state           <=  HIT;
        iomem_valid     <=  0;

        case(state_bosaltma)
            BOSTA:begin
                if(!reset_i && state_bosaltma==BOSTA)begin
                        counter         <=  0;
                        bosaltma_aktif  <=  1;
                        state_bosaltma  <=  SIL;
                        
                end
            end
            SIL:begin
                tag0  [counter]         <=  0;
                tag1  [counter]         <=  0;
                onay0 [counter]         <=  0;
                onay1 [counter]         <=  0;
                lru0  [counter]         <=  0;
                lru1  [counter]         <=  0;
                dirty0[counter]         <=  0;
                dirty1[counter]         <=  0;

                adress_next[9:2]        <=  counter;
                write0                  <=  4'hf;
                write1                  <=  4'hf;
                data_next               <=  32'b0;
                counter                 <=  counter     +    8'b1;
                if(counter == 8'hff)begin
                    state_bosaltma         <=  SILME_BITTI;
                end
            end

            SILME_BITTI:begin
                counter         <=  0;
                state_bosaltma  <=  BOSTA;
                bosaltma_aktif  <=  0;
            end

        endcase
    end

    else begin

        case(state)

            HIT:begin
                if(!stall_i)begin
                    write0          <=   0      ;
                    write1          <=   0      ;
                    read0           <=   0      ;
                    read1           <=   0      ;
                    data_next       <=   32'b0  ;
                    adress_next     <=   32'b0  ;

                    if(!veriyolu_aktif)begin
                        if(hit0)begin
                            if(write_en)begin
                                write0                   <=   wstrb_i;
                                dirty0[adress_i[9:2]]    <=   1;
                                adress_next              <=   adress_i;
                                data_next                <=   data_i;
                            end
                            else if (read_en)begin
                                read0           <=   1;
                                adress_next     <=   adress_i;
                            end      
                            if((lru1[adress_i[9:2]]!=2'h3) && (write_en || read_en))begin
                                lru1[adress_i[9:2]]<=lru1[adress_i[9:2]]  +   2'b1;
                            end
                        end

                        if(hit1)begin
                            if(write_en)begin
                                write1                   <=   wstrb_i;
                                dirty1[adress_i[9:2]]    <=   1;
                                adress_next              <=   adress_i;
                                data_next                <=   data_i;
                            end
                            else if (read_en)begin
                                read1           <=   1;
                                adress_next     <=   adress_i;
                            end
                            if((lru0[adress_i[9:2]]!=2'h3) && (write_en || read_en))begin
                                lru0[adress_i[9:2]]<=lru0[adress_i[9:2]]  +   2'b1;
                            end
                        end

                        if(!hit0 && !hit1)begin
                              if(write_en)  begin
                                adress_next     <=  adress_i  ;
                                write_next      <=  wstrb_i   ;
                                state           <=  HAFIZA_YAZ;
                                data_next       <=  data_i    ;
                                stall           <=  1;
                              end 
                              else if(read_en)  begin
                                read0           <=  1;
                                read1           <=  1;
                                adress_next     <=  adress_i  ;
                                state           <=  HAFIZA_CEK;
                                write_next      <=  0         ;
                                stall           <=  1         ;
                              end       
                              else begin
                                write_next      <=   0;
                                adress_next     <=   0;
                                state           <=   HIT;
                              end
                        end
                    end
                end
            end 

  

            HAFIZA_YAZ:begin
               iomem_valid     <=   1                        ;
               iomem_addr      <=   {adress_next[31:2],2'b0} ;
               iomem_wstrb     <=   write_next               ;
               iomem_wdata     <=   data_next                ;
               if(iomem_ready)begin
                    iomem_valid     <=   0      ;
                    iomem_addr      <=   32'b0  ;
                    iomem_wstrb     <=   4'b0   ;
                    iomem_wdata     <=   32'b0  ;
                    state           <=   BITTI  ;
               end

            end
            HAFIZA_CEK:begin
                if(lru0[adress_next[9:2]]<=lru1[adress_next[9:2]])begin
                        if(dirty1[adress_next[9:2]])begin
                                iomem_valid     <=   1               ;
                                iomem_addr      <=   {tag1[adress_next[31:2]],adress_next[9:2],2'b0} ;
                                iomem_wstrb     <=   4'b1111                                      ;
                                iomem_wdata     <=   {data13_o,data12_o,data11_o,data10_o}           ;
                                if(iomem_ready)begin
                                    iomem_valid                 <=   0;
                                    iomem_addr                  <=   32'b0  ;
                                    iomem_wstrb                 <=   4'b0   ;
                                    iomem_wdata                 <=   32'b0  ;
                                    read0                       <=   0      ;
                                    dirty1[adress_next[9:2]]    <=   0;
                                end
                        end
                        else begin
                                iomem_valid     <=   1                         ;
                                iomem_addr      <=   {adress_next[31:2],2'b0}  ;
                                iomem_wstrb     <=   4'b0                      ;
                                read0           <=   0                         ;
                                if(iomem_ready)begin
                                    iomem_valid                 <=   0                 ;
                                    iomem_addr                  <=   32'b0             ;
                                    iomem_wstrb                 <=   4'b0              ;
                                    iomem_wdata                 <=   32'b0             ;
                                    write1                      <=   4'b1111           ;
                                    data_next                   <=   iomem_rdata       ;
                                    state                       <=   BITTI             ;
                                    onay1[adress_next[9:2]]     <=   1                 ;
                                    tag1[adress_next[9:2]]      <=   adress_next[31:10];
                                end
                        end
                end
                else begin
                    if(dirty0[adress_next[9:2]])begin
                        iomem_valid     <=   1                                               ;
                        iomem_addr      <=   {tag0[adress_next[9:2]],adress_next[9:2],2'b0} ;
                        iomem_wstrb     <=   4'b1111                                      ;
                        iomem_wdata     <=   {data03_o,data02_o,data01_o,data00_o}           ;
                            if(iomem_ready)begin
                                iomem_valid                 <=   0      ;
                                iomem_addr                  <=   32'b0  ;
                                iomem_wstrb                 <=   4'b0   ;
                                iomem_wdata                 <=   32'b0  ;
                                read1                       <=   0      ;
                                dirty0[adress_next[9:2]]    <=   0      ; 
                            end
                    end
                    else begin
                        iomem_valid     <=   1                         ;
                        iomem_addr      <=   {adress_next[31:2],2'b0}  ;
                        iomem_wstrb     <=   4'b0                      ;
                        read1           <=   0                         ; 
                        if(iomem_ready)begin
                            iomem_valid                 <=   0                 ;
                            iomem_addr                  <=   32'b0             ;
                            iomem_wstrb                 <=   4'b0              ;
                            iomem_wdata                 <=   32'b0             ;
                            write0                      <=   4'b1111           ;
                            data_next                   <=   iomem_rdata       ;
                            state                       <=   BITTI             ;
                            onay0[adress_next[9:2]]     <=   1                 ;
                            tag0[adress_next[9:2]]      <=   adress_next[31:10];
                        end
                    end
                end
            
            end

            BITTI:begin
                iomem_valid     <=      0;
                iomem_wstrb     <=      0;
                iomem_addr      <=      32'b0; 
                iomem_wdata     <=      32'b0;
                write1          <=      4'b0;
                write0          <=      4'b0;
                stall           <=      0;
                state           <=      HIT;
            end
        endcase
    end
    
end



//----------------------------------
//HIT-MISS
//----------------------------------


always @(*)begin

   if (onay1[adress_i[9:2]] && tag1[adress_i[9:2]]==adress_i[31:10] && adress_i!=32'h3000_0000 && adress_i!=32'h3000_0004) begin
      hit1=1;
   end
   else begin
      hit1=0;
   end

end


always @(*)begin

   if (onay0[adress_i[9:2]] && tag0[adress_i[9:2]]==adress_i[31:10] && adress_i!=32'h3000_0000 && adress_i!=32'h3000_0004) begin
      hit0=1;
   end 
   else begin
      hit0=0;
   end

end





//-----------------------------------------
// RAM 1. YOLU
//-----------------------------------------
ram8bit ramm0_0
 (
     .clk         (clk_i                ),
     .w_en        (write0[0]            ),
     .r_en        (read0                ),
     .addr        (adress_next[9:2]    ),
     .data_in     (data_next[7:0]       ),
     .data_o      (data00_o              )
 );

 ram8bit ramm0_1
 (
     .clk         (clk_i                ),
     .w_en        (write0[1]            ),
     .r_en        (read0                ),
     .addr        (adress_next[9:2]    ),
     .data_in     (data_next[15:8]      ),
     .data_o      (data01_o              )
 );


 ram8bit ramm0_2
 (
     .clk         (clk_i                 ),
     .w_en        (write0[2]             ),
     .r_en        (read0                 ),
     .addr        (adress_next[9:2]      ),
     .data_in     (data_next[23:16]      ),
     .data_o      (data02_o              )
 );


 ram8bit ramm0_3
 (
     .clk         (clk_i                ),
     .w_en        (write0[3]            ),
     .r_en        (read0                ),
     .addr        (adress_next[9:2]     ),
     .data_in     (data_next[31:24]     ),
     .data_o      (data03_o             )
 );
//-----------------------------------------
// RAM 2. YOLU
//-----------------------------------------

ram8bit ramm1_0
 (
     .clk         (clk_i                ),
     .w_en        (write1[0]            ),
     .r_en        (read1                ),
     .addr        (adress_next[9:2]    ),
     .data_in     (data_next[7:0]       ),
     .data_o      (data10_o             )
 );

 ram8bit ramm1_1
 (
     .clk         (clk_i                ),
     .w_en        (write1[1]            ),
     .r_en        (read1                ),
     .addr        (adress_next[9:2]    ),
     .data_in     (data_next[15:8]      ),
     .data_o      (data11_o             )
 );


 ram8bit ramm1_2
 (
     .clk         (clk_i                ),
     .w_en        (write1[2]            ),
     .r_en        (read1                ),
     .addr        (adress_next[9:2]    ),
     .data_in     (data_next[23:16]     ),
     .data_o      (data12_o             )
 );


 ram8bit ramm1_3
 (
     .clk         (clk_i                ),
     .w_en        (write1[3]            ),
     .r_en        (read1                ),
     .addr        (adress_next[9:2]    ),
     .data_in     (data_next[31:24]     ),
     .data_o      (data13_o             )
 );





endmodule