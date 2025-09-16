// Testbench for toggle coverage analysis
module tb_toggle_coverage;

    // Clock and reset
    logic        clk;
    logic        rst_n;
    
    // DUT signals
    logic [31:0] data_in;
    logic [7:0]  addr;
    logic        wr_en;
    logic        rd_en;
    logic [31:0] data_out;
    logic        busy;
    logic        error;
    
    // Test control variables
    int          test_count;
    logic [31:0] expected_data;
    logic [31:0] read_data;
    
    // Coverage groups for toggle coverage tracking
    covergroup cg_data_toggles @(posedge clk);
        data_in_toggles: coverpoint data_in {
            bins zero        = {32'h00000000};
            bins all_ones    = {32'hFFFFFFFF};
            bins alternating = {32'hAAAAAAAA, 32'h55555555};
            bins walking_1   = {32'h00000001, 32'h00000002, 32'h00000004, 32'h00000008,
                               32'h00000010, 32'h00000020, 32'h00000040, 32'h00000080};
            bins walking_0   = {32'hFFFFFFFE, 32'hFFFFFFFD, 32'hFFFFFFFB, 32'hFFFFFFF7,
                               32'hFFFFFFEF, 32'hFFFFFFDF, 32'hFFFFFFBF, 32'hFFFFFF7F};
            bins small_range = {[32'h10000000:32'h100000FF]}; // Limited range for testing
        }
        
        addr_toggles: coverpoint addr {
            bins cpu_space    = {[8'h00:8'h3F]};
            bins dma_space    = {[8'h40:8'h7F]};
            bins mem_space    = {[8'h80:8'hBF]};
            bins ctrl_space   = {[8'hC0:8'hFF]};
        }
        
        control_signals: coverpoint {wr_en, rd_en} {
            bins idle   = {2'b00};
            bins write  = {2'b10};
            bins read   = {2'b01};
            bins both   = {2'b11}; // May cause conflicts, good for testing
        }
        
        cross data_in_toggles, addr_toggles, control_signals;
    endgroup
    
    // Instantiate coverage
    cg_data_toggles cg_toggles = new();
    
    // Instantiate DUT
    top_module dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .addr(addr),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_out(data_out),
        .busy(busy),
        .error(error)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    // Reset generation
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
        $display("Reset released at time %0t", $time);
    end
    
    // Main test sequence
    initial begin
        $display("Starting Toggle Coverage Test");
        
        // Initialize signals
        data_in = 0;
        addr = 0;
        wr_en = 0;
        rd_en = 0;
        test_count = 0;
        
        // Wait for reset
        wait(rst_n);
        @(posedge clk);
        
        // Test Phase 1: Basic register access patterns
        $display("Phase 1: Basic Register Access");
        test_basic_register_access();
        
        // Test Phase 2: Walking bit patterns
        $display("Phase 2: Walking Bit Patterns");
        test_walking_patterns();
        
        // Test Phase 3: Random data patterns
        $display("Phase 3: Random Data Patterns");
        test_random_patterns();
        
        // Test Phase 4: Address space coverage
        $display("Phase 4: Address Space Coverage");
        test_address_coverage();
        
        // Test Phase 5: DMA operations
        $display("Phase 5: DMA Operations");
        test_dma_operations();
        
        // Test Phase 6: Memory operations
        $display("Phase 6: Memory Operations");
        test_memory_operations();
        
        // Test Phase 7: CPU register file
        $display("Phase 7: CPU Register File");
        test_cpu_registers();
        
        // Test Phase 8: Stress testing
        $display("Phase 8: Stress Testing");
        test_stress_patterns();
        
        // Test Phase 9: Corner cases
        $display("Phase 9: Corner Cases");
        test_corner_cases();
        
        // Test Phase 10: Long running operations
        $display("Phase 10: Long Running Operations");
        test_long_operations();
        
        // Final coverage report
        $display("Test completed. Total operations: %0d", test_count);
        $display("Coverage: %0.2f%%", cg_toggles.get_coverage());
        
        #1000;
        $finish;
    end
    
    // Task: Basic register access
    task test_basic_register_access();
        logic [31:0] test_patterns[];
        test_patterns = '{32'h00000000, 32'hFFFFFFFF, 32'hAAAAAAAA, 32'h55555555};
        
        foreach(test_patterns[i]) begin
            // Test all address spaces with basic patterns
            for (int addr_val = 0; addr_val < 256; addr_val += 4) begin
                write_register(addr_val[7:0], test_patterns[i]);
                read_register(addr_val[7:0]);
                if (addr_val % 32 == 0) @(posedge clk);
            end
        end
    endtask
    
    // Task: Walking bit patterns
    task test_walking_patterns();
        logic [31:0] walking_1, walking_0;
        int addr_val, addr_plus_4;
        
        // Walking 1's
        for (int bit_pos = 0; bit_pos < 32; bit_pos++) begin
            walking_1 = 1 << bit_pos;
            walking_0 = ~walking_1;
            
            for (addr_val = 0; addr_val < 64; addr_val += 8) begin
                addr_plus_4 = addr_val + 4;
                write_register(addr_val[7:0], walking_1);
                write_register(addr_plus_4[7:0], walking_0);
                
                read_register(addr_val[7:0]);
                read_register(addr_plus_4[7:0]);
            end
            
            if (bit_pos % 4 == 0) begin
                repeat(10) @(posedge clk); // Let counters increment
            end
        end
    endtask
    
    // Task: Random patterns
    task test_random_patterns();
        for (int i = 0; i < 1000; i++) begin
            addr = $random % 256;
            data_in = $random;
            
            // Random operations
            case ($random % 4)
                0: begin
                    wr_en = 1;
                    rd_en = 0;
                end
                1: begin
                    wr_en = 0;
                    rd_en = 1;
                end
                2: begin
                    wr_en = 1;
                    rd_en = 1;
                end
                default: begin
                    wr_en = 0;
                    rd_en = 0;
                end
            endcase
            
            @(posedge clk);
            wr_en = 0;
            rd_en = 0;
            
            if (i % 100 == 0) begin
                repeat(5) @(posedge clk); // Let internal state machines run
            end
        end
    endtask
    
    // Task: Address space coverage
    task test_address_coverage();
        logic [31:0] data_patterns[];
        data_patterns = '{32'h12345678, 32'h87654321, 32'hA5A5A5A5, 32'h5A5A5A5A};
        
        // CPU address space (0x00-0x3F)
        for (int i = 0; i < 64; i++) begin
            write_register(i[7:0], data_patterns[i % 4]);
            read_register(i[7:0]);
        end
        
        // DMA address space (0x40-0x7F)
        for (int i = 64; i < 128; i++) begin
            write_register(i[7:0], data_patterns[i % 4] ^ 32'hFFFFFFFF);
            read_register(i[7:0]);
        end
        
        // Memory address space (0x80-0xBF)
        for (int i = 128; i < 192; i++) begin
            write_register(i[7:0], {data_patterns[i % 4][15:0], data_patterns[i % 4][31:16]});
            read_register(i[7:0]);
        end
        
        // Control address space (0xC0-0xFF)
        for (int i = 192; i < 256; i++) begin
            write_register(i[7:0], data_patterns[i % 4] + i);
            read_register(i[7:0]);
        end
    endtask
    
    // Task: DMA operations simulation
    task test_dma_operations();
        // Setup DMA channels
        for (int ch = 0; ch < 4; ch++) begin
            // Source address
            write_register(8'h40 + (ch * 4), 32'h1000_0000 + (ch * 32'h1000));
            // Destination address  
            write_register(8'h50 + (ch * 4), 32'h2000_0000 + (ch * 32'h1000));
            // Transfer count
            write_register(8'h60 + (ch * 4), 32'h100 + ch * 16);
            // Control register - enable channel
            write_register(8'h70 + (ch * 4), 32'h0000_0001);
        end
        
        // Enable global DMA
        write_register(8'h78, 32'h0000_0001);
        
        // Let DMA run for a while
        repeat(200) @(posedge clk);
        
        // Check status registers
        for (int ch = 0; ch < 4; ch++) begin
            read_register(8'h74 + (ch * 4)); // Status register
        end
        
        // Disable DMA
        write_register(8'h78, 32'h0000_0000);
    endtask
    
    // Task: Memory operations
    task test_memory_operations();
        // Configure memory controller
        write_register(8'h80, 32'h1000_0000); // Base address
        write_register(8'h81, 32'h0010_0000); // Size (1MB)
        write_register(8'h82, 32'h0000_0001); // Enable
        
        // Test cache operations
        for (int i = 0; i < 8; i++) begin
            // Cache data
            write_register(8'h90 + i, 32'hCAFE_0000 + i);
            // Cache tags
            write_register(8'h98 + i, 32'h8000_0000 + (i << 8));
        end
        
        // Cache control
        write_register(8'h88, 32'h0000_0007); // Enable cache
        
        // Perform memory accesses
        for (int i = 0; i < 32; i++) begin
            write_register(8'h80 + (i % 8), 32'hDEAD_0000 + i);
            read_register(8'h80 + (i % 8));
        end
        
        // Read cache statistics
        read_register(8'h89); // Cache miss count
        read_register(8'h8A); // Cache hit count
        read_register(8'h8B); // Cache valid bits
        read_register(8'h8C); // Cache dirty bits
    endtask
    
    // Task: CPU register file testing
    task test_cpu_registers();
        // Test general purpose registers
        for (int reg_num = 0; reg_num < 16; reg_num++) begin
            write_register(reg_num[7:0], 32'h1111_0000 + (reg_num << 8) + reg_num);
            read_register(reg_num[7:0]);
        end
        
        // Test special purpose registers
        write_register(8'h10, 32'h0000_1000); // PC
        write_register(8'h11, 32'hFFFF_FFF0); // SP
        write_register(8'h12, 32'h0000_2000); // LR
        write_register(8'h13, 32'h0000_001F); // PSR
        write_register(8'h14, 32'h0000_00FF); // Flags
        write_register(8'h15, 32'h0000_FFFF); // Timer
        write_register(8'h16, 32'h8000_0001); // Cache control
        write_register(8'h17, 32'h0000_00AA); // Cache config
        
        // Read back special registers
        for (int reg_num = 8'h10; reg_num <= 8'h17; reg_num++) begin
            read_register(reg_num[7:0]);
        end
        
        // Test ALU operations (addresses 0x20-0x2F with bit 5 set)
        for (int op = 0; op < 16; op++) begin
            write_register(8'h20 + op, 32'h1234_5678);
            read_register(8'h20 + op);
        end
    endtask
    
    // Task: Stress testing with rapid toggles
    task test_stress_patterns();
        logic [31:0] toggle_data;
        int cycle, addr_val, shift;
        logic [31:0] pattern1, pattern2;
        
        // Rapid bit toggling
        for (cycle = 0; cycle < 100; cycle++) begin
            toggle_data = (cycle % 2) ? 32'hFFFFFFFF : 32'h00000000;
            
            for (addr_val = 0; addr_val < 32; addr_val++) begin
                write_register(addr_val[7:0], toggle_data);
                toggle_data = ~toggle_data;
            end
            @(posedge clk);
        end
        
        // Checkerboard patterns
        for (shift = 0; shift < 32; shift++) begin
            pattern1 = 32'hAAAAAAAA >> shift;
            pattern2 = 32'h55555555 >> shift;
            
            write_register(8'h00 + shift % 32, pattern1);
            write_register(8'h20 + shift % 32, pattern2);
            write_register(8'h40 + shift % 32, pattern1 ^ pattern2);
            write_register(8'h60 + shift % 32, pattern1 & pattern2);
            
            if (shift % 8 == 0) @(posedge clk);
        end
    endtask
    
    // Task: Corner cases
    task test_corner_cases();
        // Test reset behavior
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Test simultaneous read/write
        for (int i = 0; i < 16; i++) begin
            addr = i;
            data_in = 32'hFEED_0000 + i;
            wr_en = 1;
            rd_en = 1;
            @(posedge clk);
            wr_en = 0;
            rd_en = 0;
            @(posedge clk);
        end
        
        // Test maximum values
        write_register(8'hFF, 32'hFFFFFFFF);
        write_register(8'hFE, 32'h80000000);
        write_register(8'hFD, 32'h7FFFFFFF);
        write_register(8'hFC, 32'h00000001);
        
        // Read them back
        read_register(8'hFF);
        read_register(8'hFE);
        read_register(8'hFD);
        read_register(8'hFC);
    endtask
    
    // Task: Long running operations
    task test_long_operations();
        // Setup long DMA transfer
        write_register(8'h40, 32'h1000_0000); // DMA src
        write_register(8'h50, 32'h2000_0000); // DMA dst  
        write_register(8'h60, 32'h0000_1000); // Large count
        write_register(8'h70, 32'h0000_0001); // Enable
        write_register(8'h78, 32'h0000_0001); // Global enable
        
        // Let it run while doing other operations
        for (int i = 0; i < 500; i++) begin
            write_register($random % 256, $random);
            if (i % 10 == 0) begin
                read_register(8'h74); // Check DMA status
            end
            @(posedge clk);
        end
        
        // Final status check
        read_register(8'h79); // Global status
    endtask
    
    // Helper task: Write to register
    task write_register(input logic [7:0] address, input logic [31:0] data);
        @(posedge clk);
        addr = address;
        data_in = data;
        wr_en = 1;
        rd_en = 0;
        @(posedge clk);
        wr_en = 0;
        test_count++;
        $display("Write: Addr=0x%02X, Data=0x%08X at time %0t", address, data, $time);
    endtask
    
    // Helper task: Read from register
    task read_register(input logic [7:0] address);
        @(posedge clk);
        addr = address;
        data_in = 32'h0;
        wr_en = 0;
        rd_en = 1;
        @(posedge clk);
        rd_en = 0;
        read_data = data_out;
        test_count++;
        $display("Read:  Addr=0x%02X, Data=0x%08X at time %0t", address, read_data, $time);
    endtask
    
    // Monitor for debugging
    always @(posedge clk) begin
        if (wr_en || rd_en) begin
            $display("Time %0t: addr=0x%02X, data_in=0x%08X, data_out=0x%08X, wr=%b, rd=%b, busy=%b, error=%b", 
                     $time, addr, data_in, data_out, wr_en, rd_en, busy, error);
        end
    end
    
    // Coverage sampling is automatic via @(posedge clk) in covergroup definition
    
    // Timeout watchdog
    initial begin
        #1000000; // 1ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end
    
endmodule

// Simple DUT module for toggle coverage testing
module top_module (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] data_in,
    input  logic [7:0]  addr,
    input  logic        wr_en,
    input  logic        rd_en,
    output logic [31:0] data_out,
    output logic        busy,
    output logic        error
);
    
    // Simple register file for toggle coverage
    logic [31:0] registers [0:255];
    logic [31:0] data_out_reg;
    logic        busy_reg;
    logic        error_reg;
    
    // Register file operations
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 256; i++) begin
                registers[i] <= 32'h0;
            end
            data_out_reg <= 32'h0;
            busy_reg <= 1'b0;
            error_reg <= 1'b0;
        end else begin
            if (wr_en && !rd_en) begin
                registers[addr] <= data_in;
                busy_reg <= 1'b1;
                error_reg <= 1'b0;
            end else if (rd_en && !wr_en) begin
                data_out_reg <= registers[addr];
                busy_reg <= 1'b1;
                error_reg <= 1'b0;
            end else if (wr_en && rd_en) begin
                // Conflict - set error
                error_reg <= 1'b1;
                busy_reg <= 1'b1;
            end else begin
                busy_reg <= 1'b0;
                error_reg <= 1'b0;
            end
        end
    end
    
    // Output assignments
    assign data_out = data_out_reg;
    assign busy = busy_reg;
    assign error = error_reg;
    
endmodule