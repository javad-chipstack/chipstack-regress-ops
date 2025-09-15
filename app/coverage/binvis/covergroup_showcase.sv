// covergroup_showcase.sv - Simplified Version
// Essential SystemVerilog covergroup examples

module covergroup_showcase;

  // Basic signals
  logic clk;
  logic [7:0] data;
  logic [3:0] addr;
  logic valid;
  logic ready;
  logic [1:0] cmd;
  
  typedef enum {IDLE, ACTIVE, DONE} state_t;
  state_t state;

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // ============================================================================
  // 1. Basic Value Coverage
  // ============================================================================
  covergroup basic_cg @(posedge clk);
    data_cp: coverpoint data {
      bins low = {[0:63]};
      bins mid = {[64:191]};
      bins high = {[192:255]};
      bins zero = {0};
      bins max = {255};
    }
    
    addr_cp: coverpoint addr {
      bins all_addr[] = {[0:15]};  // Auto bins for each value
    }
  endgroup

  // ============================================================================
  // 2. Cross Coverage
  // ============================================================================
  covergroup cross_cg @(posedge clk);
    data_cp: coverpoint data {
      bins small_bin = {[0:127]};
      bins large_bin = {[128:255]};
    }
    
    cmd_cp: coverpoint cmd {
      bins read = {0};
      bins write = {1};
      bins other = {[2:3]};
    }
    
    // Cross coverage
    data_cmd_cross: cross data_cp, cmd_cp;
  endgroup

  // ============================================================================
  // 3. Transition Coverage
  // ============================================================================
  covergroup transition_cg @(posedge clk);
    state_trans: coverpoint state {
      bins idle_to_active = (IDLE => ACTIVE);
      bins active_to_done = (ACTIVE => DONE);
      bins done_to_idle = (DONE => IDLE);
      bins stay_active = (ACTIVE => ACTIVE);
    }
  endgroup

  // ============================================================================
  // 4. Conditional Coverage
  // ============================================================================
  covergroup conditional_cg @(posedge clk iff valid);
    valid_data_cp: coverpoint data {
      bins valid_range = {[1:254]};
      bins boundaries = {0, 255};
    }
    
    handshake_cp: coverpoint {valid, ready} {
      bins wait_state = {2'b10};
      bins transfer = {2'b11};
    }
  endgroup

  // Create covergroup instances
  basic_cg basic_inst = new();
  cross_cg cross_inst = new();
  transition_cg trans_inst = new();
  conditional_cg cond_inst = new();

  // ============================================================================
  // Simple Test Stimulus
  // ============================================================================
  initial begin
    // Initialize
    data = 0;
    addr = 0;
    valid = 0;
    ready = 0;
    cmd = 0;
    state = IDLE;
    
    // Generate test patterns
    repeat (200) begin
      @(posedge clk);
      data = $random;
      addr = $random;
      valid = $random & 1;
      ready = $random & 1;
      cmd = $random;
      
      // Simple state machine
      case (state)
        IDLE: if (valid) state = ACTIVE;
        ACTIVE: if (ready) state = DONE;
        DONE: state = IDLE;
      endcase
    end
    
    // Show coverage results
    $display("Basic Coverage: %0.1f%%", basic_inst.get_coverage());
    $display("Cross Coverage: %0.1f%%", cross_inst.get_coverage());
    $display("Transition Coverage: %0.1f%%", trans_inst.get_coverage());
    $display("Conditional Coverage: %0.1f%%", cond_inst.get_coverage());
    
    $finish;
  end

endmodule