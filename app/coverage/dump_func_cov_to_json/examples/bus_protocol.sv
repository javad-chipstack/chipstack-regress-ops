// bus_protocol.sv - Bus Interface Coverage
// SystemVerilog covergroup examples for bus protocol verification

module bus_protocol;

  // Bus interface signals
  logic clk;
  logic reset_n;
  logic [31:0] address;
  logic [7:0] wdata;
  logic [7:0] rdata;
  logic [2:0] burst_len;
  logic write_en;
  logic read_en;
  logic ack;
  logic error;
  
  typedef enum {BUS_IDLE, BUS_READ, BUS_WRITE, BUS_BURST} bus_state_t;
  bus_state_t bus_state;

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // ============================================================================
  // 1. Address Coverage
  // ============================================================================
  covergroup address_cg @(posedge clk);
    addr_cp: coverpoint address {
      bins low_mem = {[32'h0000_0000:32'h0000_FFFF]};
      bins mid_mem = {[32'h0001_0000:32'hFFFF_0000]};
      bins high_mem = {[32'hFFFF_0001:32'hFFFF_FFFF]};
      
      // Special addresses
      bins zero_addr = {32'h0000_0000};
      bins max_addr = {32'hFFFF_FFFF};
      
      // Alignment coverage
      wildcard bins word_aligned = {32'b????_????_????_????_????_????_????_??00};
      wildcard bins unaligned = {32'b????_????_????_????_????_????_????_??01,
                                 32'b????_????_????_????_????_????_????_??10,
                                 32'b????_????_????_????_????_????_????_??11};
    }
  endgroup

  // ============================================================================
  // 2. Data Pattern Coverage
  // ============================================================================
  covergroup data_patterns_cg @(posedge clk iff write_en);
    wdata_cp: coverpoint wdata {
      bins all_zeros = {8'h00};
      bins all_ones = {8'hFF};
      bins alternating = {8'hAA, 8'h55};
      bins walking_ones[] = {8'h01, 8'h02, 8'h04, 8'h08, 
                             8'h10, 8'h20, 8'h40, 8'h80};
      bins normal_data = {[8'h01:8'hFE]};
    }
    
    rdata_cp: coverpoint rdata {
      bins low_data = {[0:31]};
      bins mid_data = {[32:63], [64:95], [96:127]};
      bins high_data = {[128:159], [160:191], [192:223], [224:255]};
      bins special_patterns = {8'hA5, 8'h5A, 8'hAA, 8'h55};
    }
  endgroup

  // ============================================================================
  // 3. Protocol State Coverage
  // ============================================================================
  covergroup protocol_cg @(posedge clk);
    operation_cp: coverpoint {write_en, read_en} {
      bins idle = {2'b00};
      bins write_op = {2'b10};
      bins read_op = {2'b01};
      illegal_bins both_ops = {2'b11}; // Both operations shouldn't happen
    }
    
    state_cp: coverpoint bus_state {
      bins all_states[] = {BUS_IDLE, BUS_READ, BUS_WRITE, BUS_BURST};
    }
    
    // State transitions
    state_trans_cp: coverpoint bus_state {
      bins start_write = (BUS_IDLE => BUS_WRITE);
      bins start_read = (BUS_IDLE => BUS_READ);
      bins start_burst = (BUS_IDLE => BUS_BURST);
      bins write_done = (BUS_WRITE => BUS_IDLE);
      bins read_done = (BUS_READ => BUS_IDLE);
      bins burst_done = (BUS_BURST => BUS_IDLE);
      bins burst_continue = (BUS_BURST => BUS_BURST);
    }
    
    // Response coverage
    response_cp: coverpoint {ack, error} {
      bins success = {2'b10};
      bins bus_error = {2'b01};
      bins no_response = {2'b00};
      illegal_bins invalid = {2'b11}; // Can't have both ack and error
    }
  endgroup

  // ============================================================================
  // 4. Burst Transaction Coverage
  // ============================================================================
  covergroup burst_cg @(posedge clk iff (bus_state == BUS_BURST));
    burst_len_cp: coverpoint burst_len {
      bins single = {0};
      bins short_burst = {[1:3]};
      bins long_burst = {[4:7]};
    }
    
    burst_addr_cp: coverpoint address[3:0] {
      bins start_aligned = {4'h0};
      bins start_unaligned = {[4'h1:4'hF]};
    }
    
    // Cross coverage for burst characteristics
    burst_cross: cross burst_len_cp, burst_addr_cp {
      ignore_bins unaligned_long = binsof(burst_addr_cp.start_unaligned) && 
                                   binsof(burst_len_cp.long_burst);
    }
  endgroup

  // Create covergroup instances
  address_cg addr_inst = new();
  data_patterns_cg data_inst = new();
  protocol_cg proto_inst = new();
  burst_cg burst_inst = new();

  // ============================================================================
  // Bus Protocol Logic
  // ============================================================================
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      bus_state <= BUS_IDLE;
      ack <= 0;
      error <= 0;
      rdata <= 0;
    end else begin
      case (bus_state)
        BUS_IDLE: begin
          ack <= 0;
          error <= 0;
          if (write_en) 
            bus_state <= BUS_WRITE;
          else if (read_en) 
            bus_state <= BUS_READ;
          else if (burst_len > 0)
            bus_state <= BUS_BURST;
        end
        
        BUS_WRITE: begin
          if (address > 32'hF000_0000) begin // Error region
            ack <= 0;
            error <= 1;
          end else begin
            ack <= 1;
            error <= 0;
          end
          bus_state <= BUS_IDLE;
        end
        
        BUS_READ: begin
          if (address > 32'hF000_0000) begin // Error region
            ack <= 0;
            error <= 1;
            rdata <= 0;
          end else begin
            ack <= 1;
            error <= 0;
            rdata <= address[7:0] ^ 8'hA5; // Simple read data pattern
          end
          bus_state <= BUS_IDLE;
        end
        
        BUS_BURST: begin
          ack <= 1;
          if (burst_len == 0)
            bus_state <= BUS_IDLE;
          else
            burst_len <= burst_len - 1;
        end
      endcase
    end
  end

  // ============================================================================
  // Test Stimulus
  // ============================================================================
  initial begin
    // Initialize signals
    reset_n = 0;
    address = 0;
    wdata = 0;
    burst_len = 0;
    write_en = 0;
    read_en = 0;
    bus_state = BUS_IDLE;
    
    // Reset sequence
    repeat (5) @(posedge clk);
    reset_n = 1;
    repeat (2) @(posedge clk);
    
    // Generate various bus transactions
    repeat (500) begin
      @(posedge clk);
      
      // Generate targeted addresses to hit coverage bins
      case ($random % 20)
        0,1: address = $random & 32'hFFFF; // Low memory
        2,3: address = 32'h0000_0000; // Zero address
        4,5: address = 32'hFFFF_FFFF; // Max address
        6,7: address = 32'hF000_0001; // Error region
        8,9: address = 32'h0000_0004; // Word aligned
        10,11: address = 32'h0000_0005; // Unaligned
        default: address = $random; // Random addresses
      endcase
        
      // Generate targeted data patterns
      case ($random % 15)
        0: wdata = 8'h00; // All zeros
        1: wdata = 8'hFF; // All ones
        2: wdata = 8'hAA; // Alternating
        3: wdata = 8'h55; // Alternating
        4: wdata = 8'h01; // Walking ones
        5: wdata = 8'h02; // Walking ones
        6: wdata = 8'h04; // Walking ones
        7: wdata = 8'h08; // Walking ones
        8: wdata = 8'h10; // Walking ones
        9: wdata = 8'h20; // Walking ones
        10: wdata = 8'h40; // Walking ones
        11: wdata = 8'h80; // Walking ones
        default: wdata = $random; // Random data
      endcase
      
      // Generate different transaction types
      case ($random % 10)
        0,1,2: begin // Write operations (30%)
          write_en = 1;
          read_en = 0;
          burst_len = 0;
        end
        
        3,4,5: begin // Read operations (30%)
          write_en = 0;
          read_en = 1;
          burst_len = 0;
        end
        
        6,7: begin // Burst operations (20%)
          write_en = 0;
          read_en = 0;
          burst_len = $random % 8;
        end
        
        default: begin // Idle (20%)
          write_en = 0;
          read_en = 0;
          burst_len = 0;
        end
      endcase
      
      // Wait for operation to complete
      if (write_en || read_en || burst_len > 0) begin
        @(posedge clk);
        write_en = 0;
        read_en = 0;
      end
    end
    
    // Display coverage summary
    $display("\n=== Bus Protocol Coverage Results ===");
    $display("Address Coverage: %0.1f%%", addr_inst.get_coverage());
    $display("Data Patterns Coverage: %0.1f%%", data_inst.get_coverage());
    $display("Protocol Coverage: %0.1f%%", proto_inst.get_coverage());
    $display("Burst Coverage: %0.1f%%", burst_inst.get_coverage());
    
    $finish;
  end

  // Coverage analysis
  final begin
    $display("\n=== Detailed Coverage Analysis ===");
    $display("Coverage Summary:");
    $display("  Address Coverage: %.2f%%", addr_inst.get_coverage());
    $display("  Data Patterns Coverage: %.2f%%", data_inst.get_coverage());
    $display("  Protocol Coverage: %.2f%%", proto_inst.get_coverage());
    $display("  Burst Coverage: %.2f%%", burst_inst.get_coverage());
    
    $display("\nOverall Coverage: %.2f%%", 
             (addr_inst.get_coverage() + data_inst.get_coverage() + 
              proto_inst.get_coverage() + burst_inst.get_coverage()) / 4.0);
  end

endmodule