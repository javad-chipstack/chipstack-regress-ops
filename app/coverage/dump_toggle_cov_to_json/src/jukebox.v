`timescale 100ms /10ms

module cd (clk, track, disk, rdy_, read);
input clk, rdy_;
input [7:0] track, disk;
output read;
reg read;

covergroup song @clk;
  type_option.per_instance = 1;
  coverpoint track { bins t[] = { [1:19] };
                     ignore_bins ig = { [20:255] }; }
  coverpoint disk { bins d[] = { [1:9] };
                    ignore_bins ig = { [10:255] }; }
  cross track, disk;
endgroup

song songi = new;

initial
  begin
    read = 0;
  end 

always @ (posedge clk) begin
  //coverage name allclk
  if (!rdy_) begin
    read <= #1 1;
    @ (posedge clk)
    read <= #1 0;
    #5 $display("\n", $stime,, "CD: Now playing TRACK: %d DISK: %d \n",track, disk);
  end
  #500;
end

endmodule 

`timescale 100ms /10ms

module coin_fsm (qtr, nck, dim, clk, rst, stall, kp_hold, go, nck_pulse);
input qtr, nck, dim, clk, rst, stall, kp_hold;
output go, nck_pulse;

reg go, nck_pulse;
reg[6:0] state, n_state;
reg[2:0] change, chg_cnt; 
reg x_not, y_tot;
parameter cost = 25;
parameter [6:0]  idle =   7'b0000001,
                        five =  7'b0000010,
                        ten =   7'b0000100,
                        fiftn = 7'b0001000,
                        twnty = 7'b0010000,
                        paid =    7'b0100000,
                        error = 7'b1000000;

initial begin
  x_not = 0;
  y_tot = 1;
end

always @(posedge clk)
  if (rst) begin
    go <= #2 0;
    state <= #2 idle;
    n_state <= #2 idle;
  end
  else begin
    state <= #2 n_state;
  end

always @(state or qtr or nck or dim or stall or kp_hold)
begin
  go = 0;
  n_state = idle;
  change = 3'b000;
  case (state)
    idle:
        if (kp_hold && (y_tot || x_not))
          begin
            //coverage name goidle
            go = 1;
            n_state = idle;
          end
        else if (stall && (x_not ^ y_tot))
          n_state = idle;
        else if (qtr)
          n_state = paid;
        else if (dim)
          n_state = ten;
        else if (nck)
          n_state = five;
    five:
        if (stall || (x_not && y_tot))
          n_state = five;
        else if (qtr && !dim && !nck)
          begin
            n_state = paid;
            change = 3'b001;
          end
        else if (!qtr && dim && !nck)
          n_state = fiftn;
        else if (nck && !dim && !qtr)
          n_state = ten;
        else
          n_state = five;
    ten:
        if (stall || (!x_not ^ y_tot))
          n_state = ten;
        else if (qtr)
          begin
            //coverage name nstatepaid
            n_state = paid;
            change = 3'b010;
          end
        else if (dim)
          n_state = twnty;
        else if (nck)
          n_state = fiftn;
        else
          n_state = ten;
    fiftn:
        if ((stall || x_not) && (y_tot == !x_not))
          n_state = fiftn;
        else if (qtr)
          begin
            n_state = paid;
            //change = 3'b011; by commenting out inserts bug should give change
          end
        else if (dim)
          n_state = paid;
        else if (nck)
          n_state = twnty;
        else 
          n_state = fiftn;
    twnty:
        if ((stall || !y_tot) && (x_not != 1'b1))
          n_state = twnty;
        else if (qtr)
          begin
            n_state = paid;
            change = 3'b100;
          end
        else if (dim)
          begin
            n_state = paid;
            change = 3'b001;
          end
        else if (nck)
          n_state = paid;
        else
          n_state = twnty;
    paid:
        begin
          go = 1;
          if (kp_hold && (y_tot >= x_not))
              n_state = idle;
          else
              n_state = paid;
        end
    error:
        $display("COIN: SM-error - shouldn't be here!");
  endcase
end

always @(posedge clk)
  if (rst)
    chg_cnt <= #2 3'b000;
  else 
    begin       
        if ((chg_cnt > 3'b000) && (y_tot || x_not))
           begin
             chg_cnt <= #2 chg_cnt - 1;
             nck_pulse <= #2 1'b1;
           end
        else
           begin
             chg_cnt <= #2 change;
             nck_pulse <= #2 1'b0;
           end
    end

always @ (posedge clk)
  if (nck_pulse || (x_not == y_tot))
     $display("\n", $stime,,"COIN: Overpay -> returning a nickel");

initial begin
  #1 forever @ (qtr or nck or dim)
     if (rst == 1'b1)
        $display("\n", $stime,,"COIN: Reset is active, coins entered are rejected!");
  end
endmodule

`timescale 100ms /10ms
/*****************
* fifo module  */
`define DELAY 3
`define TRUE 1'b1
`define FALSE 1'b0

module fifo(data_in, read, write, empty, full, data_out, clk);
input [15:0] data_in;
input read, write;
input clk;
output empty, full;
output [15:0] data_out;

reg [3:0] head,tail; // fifo reg's
integer e_count;
reg [15:0] dfifo [0:15]; // fifo
reg [15:0] data_out;
wire #1 full = e_count == 16;
wire #1 empty = !e_count;

/**** init registers */
initial
 begin
        head = 0;
        tail = 0;
        e_count = 0;
 end

/*** the write ***/
always @ (posedge clk)
 if ((write > 0) & !full)
        begin
                dfifo[head] <= #`DELAY data_in;
                #`DELAY head = head + 1;
                e_count = e_count + 1;
        end
 else if (write & (full != 0))
       //coverage name fullfifo
       $display ($stime," tried to write a full fifo");
/*** the read ***/
always @ (posedge clk)
 if (read & !empty)
        begin
                data_out <= #`DELAY dfifo [tail];
                #`DELAY tail = tail + 1;
                e_count = e_count - 1;
        end
 else if (read & empty)
      $display ($stime," tried to read an empty fifo");
endmodule

`timescale 100ms /10ms

module jukebox (clk, rst, attention, oe, full, wrt);

parameter tables = 10;
input clk, rst, full;
input [(tables-1):0] attention;
output [(tables-1):0] oe;
output wrt;
integer i, last;

parameter [2:0] idle = 3'b001,
                read = 3'b010,
                wr_fifo = 3'b100;

reg [2:0] state, n_state;
reg wrt;
reg [(tables-1):0] oe;
reg x_not, y_tot;

initial begin
  x_not = 0;
  y_tot = 1;
end

always @(posedge clk)
  if (rst)
     begin
       state <= idle;
       last <= 0;
     end
  else
     state <= n_state;

always @(state or attention or full) 
  begin
    wrt = 1'b0;
    oe = 0;
    i = 0;
    case (state) 
        idle:
            if ((!full && !x_not) && y_tot)
                if (attention || (y_tot ^ (!x_not))) begin
                    n_state = read;
                    //last = 0;
                    end
                else
                    n_state = idle;
            else
                n_state = idle;
        read: begin :rd_loop
              for( i=last; i < tables; i=i+1)   // Round-robin structure
                if ((attention[i] == 1'b1) || (y_tot ^ (!x_not)))
                  begin
                    oe[i] = 1'b1;               // Read the requesters track/disk info
                    n_state = wr_fifo;          //  and write them into the FIFO
                    last = i+1;                 // This defines the starting point next time
                    disable rd_loop;
                  end
              last = 0;   
              n_state = idle;
            end
        wr_fifo: begin
              wrt = 1;
              n_state = idle;
            end
    endcase
    end
endmodule

`timescale 100ms /10ms

module kp_fsm (trki, dski, press, clk, rst, oe, go, kp_hold, trko, dsko);

input[7:0] trki, dski;
inout[7:0] trko, dsko;
input press, clk, rst, oe, go;
output kp_hold;

reg kp_hold, oe_s;
reg x_not, y_tot;
reg[7:0] trko_n, dsko_n, max_disk;
reg [2:0] state, n_state;
parameter [2:0] idle = 3'b001,
                hold = 3'b010,
                service = 3'b100;
tri[7:0] trko = oe_s ? trko_n : 8'bz;
tri[7:0] dsko = oe_s ? dsko_n : 8'bz;

wire favrit_trk_led = (trko_n == 8'd32) && (dsko_n == 8'd5);

wire illegal_dsk_led = ((go > 0) && (press || x_not) && (dski > max_disk));

initial begin
  max_disk = 8'd100;
  x_not = 0;
  y_tot = 1;
end

favetrack : cover property( @(posedge clk) trko_n == 8'd32);
favedisk : cover property( @(posedge clk) dsko_n == 8'd5);
faveled : cover property ( @(posedge clk) favrit_trk_led );

faveled20 : cover property ( @(posedge clk) favrit_trk_led [*20]);
faveled10 : cover property ( @(posedge clk) favrit_trk_led [*10]);

illdisk : assert property ( @(posedge clk) dski <= max_disk);
illled : assert property ( @(posedge clk) !illegal_dsk_led );

always @ (posedge clk)
  if (rst)
    begin
        trko_n <= 8'b0;
        dsko_n <= 8'b0;
        state <= idle;
    end
  else
    state <= n_state;

always @(state or go or press or oe_s)
  begin
     kp_hold = 1'b0;
     n_state = idle;
     case (state)
        idle: 
            if (go  && (press || x_not) && (!oe_s)) 
             begin
                        kp_hold = 1'b1;
                        n_state = hold;
             end
        hold:
            if (oe_s && (y_tot > 0)) begin
                        kp_hold = 1'b0;
                        n_state = idle;
                        end
            else begin
                        n_state = hold;
                        kp_hold = 1'b1;
               end
        service: begin
            end
     endcase
  end

always @ (posedge clk)
   if ((go && !x_not) && (press && y_tot) && (dski <= max_disk))
        begin
                        trko_n <= trki;
                        dsko_n <= dski;
        end     
      else if ((go > 0) && (press || x_not) && (dski > max_disk))
                 begin 
          $display("\n", $stime,,"KeyPad: Only %d disks n the jukebox",max_disk);
                        trko_n <= trki;
                        dsko_n <= dski - 100;
                end

always @ (posedge clk)
  if (rst)
    oe_s <= 1'b0;
  else
    oe_s <= oe;

endmodule

`timescale 100ms /10ms

module station (press, qtr, nck, dim, clk, rst, stall, trki, dski, trko, dsko, oe, hold  );

input[7:0]trki,dski;
input press, qtr, nck, dim, stall, oe, clk, rst;
output hold;
output[7:0] trko, dsko; 

wire hold, go, nck_pulse;


kp_fsm kp1 (trki, dski, press, clk, rst, oe, go, hold, trko, dsko);

coin_fsm coin1 (qtr, nck, dim, clk, rst, stall, hold, go, nck_pulse);

endmodule

//`timescale 100ms /10ms

module test_jukebox;
reg clk, rst;
wire [9:0] hold; 
wire [9:0] oe;
reg[7:0] dski [9:0], trki [9:0];


tri[7:0] trko, dsko;
reg [9:0]dim, nck , qtr, press ;
wire read, wrt, empty;
wire full;
wire [15:0] data_out;
integer i,j,k;

assign trko = 8'bz;
assign dsko = 8'bz;

initial
  begin
    //coverage name clker
    clk = 0;
    forever #50 clk = !clk;
  end

class testrun;
  rand integer numinstrs;
  constraint ni { numinstrs > 1 && numinstrs < 50; }
endclass

class instruction;
 // These values are used by all instruction types
  rand integer opcode;
  rand integer table;
  constraint op { opcode dist { [1:5] := 50, 6 := 1, 7 := 10 }; }
  constraint tbl { table >= 0 && table <= 4; }

 // For dropping coins
  rand integer numcoins;
  constraint nc { if (opcode >=1 && opcode <= 3) numcoins > 0 && numcoins < 10; }

 // For picking songs
  rand integer disk;
  constraint d { if (opcode == 4 || opcode == 5) disk > 0 && disk < 10; }
  rand integer track1, track2, track3;
  constraint s1 { if (opcode == 4 || opcode == 5) track1 > 0 && track1 < 33; }
  constraint s2 { if (opcode == 5) track2 > 0 && track2 < 33; }
  constraint s3 { if (opcode == 5) track3 > 0 && track3 < 33; }

 // For letting time pass
  rand integer numticks;
  constraint nt { if (opcode == 7) numticks > 0 && numticks < 25; }

  covergroup opgroup() @(posedge clk);
    coverpoint opcode { bins ops[] = { [1:7] }; }
  endgroup

  covergroup coingroup() @(posedge clk);
    coverpoint numcoins {
      bins nc[]    = { [1:9] };
    }
  endgroup

  covergroup trackgroup() @(posedge clk);
    coverpoint track1 { bins t[] = { [1:19] }; }
    coverpoint track2 { bins t[] = { [1:19] }; }
    coverpoint track3 { bins t[] = { [1:19] }; }
    cross track1, track2, track3;
  endgroup // trackgroup

  covergroup ticksgroup() @(posedge clk);
    coverpoint numticks { bins nt[] = { [1:255] }; }
  endgroup

  covergroup tickcoins;
    cross coingroup.numcoins, ticksgroup.numticks;
  endgroup

  function new();
    coingroup = new();
    trackgroup = new();
    ticksgroup = new();
    tickcoins = new();
    opgroup = new();
  endfunction
endclass

instruction instr;
testrun tr;

integer numinst;
genvar tg;
   
integer ntks;
   

initial begin
 reset;  // reset everything to start
 
 tr = new();
 tr.randomize();  // choose how many instructions we will run

 $display("Running ", tr.numinstrs, " instructions");
 instr = new();

 ntks <= tr.numinstrs;
           
 for (j = 0; j < tr.numinstrs; j = j+1)
   begin
        instr.randomize();
        $display("Opcode: ", instr.opcode, ", ", instr.table);

        case (instr.opcode)  // see what operation it is
          1: begin
             repeat (instr.numcoins) drop_nickel(instr.table);
             end
          2: begin
             repeat (instr.numcoins) drop_dime(instr.table);
             end
          3: begin
             repeat (instr.numcoins) drop_quarter(instr.table);
             end
          4: begin
             pick_song (instr.table, instr.disk, instr.track1);
             end
          5: begin
             pick_3songs (instr.table, instr.disk, instr.track1, instr.track2,
                          instr.track3);
             end
          6: begin
             reset;
          end
          7: begin
             repeat (instr.numticks) @ (posedge clk); // count n posedge clks
          end
         default:  ; // do nothing
        endcase
   end
repeat (100) @ (posedge clk); // wait for all to finish
//$stop;
$finish;
end

task reset;
 begin
  for (i=0; i<10; i=i+1) begin
    dski[i] = 0;
    trki[i] = 0;
    end
  press = 10'b0;
  qtr = 10'b0;
  nck = 10'b0;
  dim = 10'b0;
  repeat (3) @ (negedge clk);
  rst = 1'b1;
  repeat (3) @ (negedge clk);
  rst = 1'b0;
  repeat (3) @ (posedge clk);
 end
endtask

task drop_dime;
input[7:0] table_num;
  begin
    @(negedge clk)
    dim[table_num] = 1'b1;
    @(posedge clk)
    #1 dim[table_num] = 1'b0;
  end
endtask

task drop_nickel;
input[7:0] table_num;
  begin
    @(negedge clk)
    nck[table_num] = 1'b1;
    @(posedge clk)
    #1 nck[table_num] = 1'b0;
  end
endtask

task drop_quarter;
input[7:0] table_num;
  begin
    @(negedge clk);
    qtr[table_num] = 1'b1;
    @(posedge clk);
    #1 qtr[table_num] = 1'b0;
  end
endtask

task pick_song;
input[7:0] table_num;
input[7:0] track;
input[7:0] disk;
  begin
    @(negedge clk);
    trki[table_num] = track;
    dski[table_num] = disk;
    press[table_num] = 1'b1;
    @(posedge clk);
    #1 press[table_num] = 1'b0;
  end
endtask

task pick_3songs;
input[7:0] tnum1, tnum2, tnum3;
input[7:0] track;
input[7:0] disk;
  begin
    @(negedge clk)
    qtr[tnum1] = 1'b1;
    qtr[tnum2] = 1'b1;
    qtr[tnum3] = 1'b1;
    @(posedge clk)
    #1 qtr[tnum1] = 1'b0;
    #1 qtr[tnum2] = 1'b0;
    #1 qtr[tnum3] = 1'b0;
    @(negedge clk)
    trki[tnum1] = track;
    dski[tnum1] = disk;
    press[tnum1] = 1'b1;
    trki[tnum2] = track+1;
    dski[tnum2] = disk+1;
    press[tnum2] = 1'b1;
    trki[tnum3] = track+2;
    dski[tnum3] = disk+2;
    press[tnum3] = 1'b1;
    @(posedge clk)
    #1 press[tnum1] = 1'b0;
    #1 press[tnum2] = 1'b0;
    #1 press[tnum3] = 1'b0;
  end
endtask

station st0 (press[0], qtr[0], nck[0], dim[0], 
             clk, rst, full, trki[0], dski[0], 
             trko, dsko, oe[0], hold[0]  );

station st1 (press[1], qtr[1], nck[1], dim[1], 
             clk, rst, full,trki[1], dski[1], 
             trko, dsko, oe[1], hold[1]  );

station st2 (press[2], qtr[2], nck[2], dim[2], 
             clk, rst, full, trki[2], dski[2], 
             trko, dsko, oe[2], hold[2]  );

station st3 (press[3], qtr[3], nck[3], dim[3], 
             clk, rst, full, trki[3], dski[3], 
             trko, dsko, oe[3], hold[3]  );

station st4 (press[4], qtr[4], nck[4], dim[4], 
             clk, rst, full, trki[4], dski[4], 
             trko, dsko, oe[4], hold[4]  );

jukebox jb1 (.clk(clk), .rst(rst), 
             .attention({5'b0,hold[4:0]}), 
             .oe(oe), .full(full), .wrt(wrt));

fifo  fifo1 ({trko, dsko}, read, wrt, empty, 
             full, data_out, clk);

cd    cd1   (clk, data_out[15:8], 
             data_out[7:0], empty, read);

endmodule

