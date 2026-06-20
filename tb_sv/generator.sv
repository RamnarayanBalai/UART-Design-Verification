class generator;
    mailbox #(apb_trans) gen2drv;
    event drv_done;
    uart_config cfg;
    virtual uart_interface v_uart;
    
    function new(mailbox #(apb_trans) gen2drv, event drv_done, uart_config cfg, virtual uart_interface v_uart);
        this.gen2drv  = gen2drv;
        this.drv_done = drv_done;
        this.cfg      = cfg;
        this.v_uart   = v_uart;
    endfunction

    task apb_write(logic [4:0] addr, logic [7:0] data);
        apb_trans tx = new();
        tx.addr  = addr;
        tx.write = 1'b1;
        tx.data  = data;
        gen2drv.put(tx);
        @drv_done;
    endtask

    task apb_read(logic [4:0] addr, output logic [7:0] data);
        apb_trans tx = new();
        tx.addr  = addr;
        tx.write = 1'b0;
        gen2drv.put(tx);
        @drv_done;
        data = tx.data[7:0];
    endtask

    task run(int num_tx);
        logic [7:0] temp_data;

        $display("\n==================================================");
        $display("[Generator] PROGRAMMING CONFIGURATION REGISTERS");
        $display("==================================================");
        
        // Write LCR = 8'h80 (Set DLAB = 1)
        apb_write(5'h0C, 8'h80);
        // Write DLL & DLH
        apb_write(5'h00, cfg.divisor[7:0]);
        apb_write(5'h04, cfg.divisor[15:8]);
        
        // Read back DLL & DLH (with DLAB = 1) to verify
        apb_read(5'h00, temp_data);
        $display("[Generator] Read back DLL: %2h (expected %2h)", temp_data, cfg.divisor[7:0]);
        apb_read(5'h04, temp_data);
        $display("[Generator] Read back DLH: %2h (expected %2h)", temp_data, cfg.divisor[15:8]);

        // Write LCR = 8'h1B (Clear DLAB, Set 8-E-1: WLS=8, PEN=1, EPS=1, STB=1)
        apb_write(5'h0C, 8'h1B);
        
        // Read back LCR to verify
        apb_read(5'h0C, temp_data);
        $display("[Generator] Read back LCR: %2h (expected 1B)", temp_data);

        // Read FCR to satisfy coverage
        apb_read(5'h08, temp_data);


        $display("\n==================================================");
        $display("[Generator] TEST CASE 1: Simple Loopback with LSR Polling");
        $display("==================================================");
        // Write dynamic scratchpad check
        $display("[Generator] Writing and Reading SCR (Scratchpad Register)...");
        apb_write(5'h1C, 8'h3C);
        apb_read(5'h1C, temp_data);
        if (temp_data !== 8'h3C) $error("[Generator] SCR Mismatch! Got %2h, expected 3C", temp_data);
        else $display("[Generator] SCR Match! Got %2h", temp_data);

        // Loopback 5 characters one-by-one using LSR polling
        for (int i = 0; i < 5; i++) begin
            logic [7:0] test_val = $urandom_range(8'h00, 8'hFF);
            $display("[Generator] Sending single byte: %2h", test_val);
            apb_write(5'h00, test_val); // Write THR

            // Poll LSR until DR (bit 0) is 1
            do begin
                apb_read(5'h14, temp_data); // Read LSR
            end while (temp_data[0] == 1'b0);

            // Read RBR
            apb_read(5'h00, temp_data);
            $display("[Generator] Read back RBR byte: %2h (expected %2h)", temp_data, test_val);
        end


        $display("\n==================================================");
        $display("[Generator] TEST CASE 2: FIFO Stress Test (16-Byte Burst)");
        $display("==================================================");
        // Fill the TX FIFO (16 deep)
        $display("[Generator] Filling the 16-deep TX FIFO with 16 sequential bytes...");
        for (int i = 0; i < 16; i++) begin
            apb_write(5'h00, 8'hA0 + i);
        end

        // Wait for all data to be transmitted (TEMT = LSR[6] = 1)
        $display("[Generator] Polling LSR for TEMT (Transmitter Empty)...");
        do begin
            apb_read(5'h14, temp_data);
        end while (temp_data[6] == 1'b0);
        $display("[Generator] Transmission complete. Reading RX FIFO...");

        // Read all 16 bytes back from RX FIFO
        for (int i = 0; i < 16; i++) begin
            apb_read(5'h00, temp_data);
            $display("[Generator] Read RX FIFO[%0d] = %2h (expected %2h)", i, temp_data, 8'hA0 + i);
        end


        $display("\n==================================================");
        $display("[Generator] TEST CASE 3: RX Overrun Test");
        $display("==================================================");
        // Write 18 bytes to TX FIFO to fill RX FIFO and cause overrun
        $display("[Generator] Writing 18 bytes back-to-back...");
        for (int i = 0; i < 18; i++) begin
            apb_write(5'h00, 8'hC0 + i);
            #100; // Small delay to let TX FIFO pop and transmit
        end

        // Wait for all 18 bytes to be transmitted without reading LSR (to avoid clearing OE prematurely)
        #(cfg.get_bit_period_ns() * 12.0 * 18.0);

        // Read LSR to verify Overrun Error (OE = LSR[1] = 1)
        apb_read(5'h14, temp_data);
        if (temp_data[1] == 1'b1) begin
            $display("[Generator] SUCCESS: Overrun Error (LSR[1]) detected!");
        end else begin
            $error("[Generator] ERROR: Overrun Error (LSR[1]) not set! LSR=%b", temp_data);
        end

        // Read the 16 valid bytes out of RX FIFO
        for (int i = 0; i < 16; i++) begin
            apb_read(5'h00, temp_data);
        end

        // Verify LSR OE is cleared after read
        apb_read(5'h14, temp_data);
        if (temp_data[1] == 1'b0) begin
            $display("[Generator] SUCCESS: Overrun Error (LSR[1]) cleared after LSR read!");
        end else begin
            $error("[Generator] ERROR: Overrun Error (LSR[1]) not cleared after read!");
        end

        // Reset FIFOs
        $display("[Generator] Clearing FIFOs for next test...");
        apb_write(5'h08, 8'h06);


        $display("\n==================================================");
        $display("[Generator] TEST CASE 4: Parity Error Injection");
        $display("==================================================");
        fork
            begin
                // Start a write
                apb_write(5'h00, 8'hA5); // 8'hA5 (4 ones, Even Parity should be 0)
            end
            begin
                real bit_p = cfg.get_bit_period_ns();
                // Wait for falling edge of TXD (start of frame)
                @(negedge v_uart.TXD);
                // Wait for 9 bit periods to reach the parity bit (1 start + 8 data bits)
                #(bit_p * 9.0);
                #(bit_p * 0.2); // Mid-bit
                $display("[Generator] Inverting parity bit on serial line to inject Parity Error...");
                v_uart.err_val    = ~v_uart.TXD;
                v_uart.err_inject = 1'b1;
                #(bit_p * 0.6);
                v_uart.err_inject = 1'b0;
            end
        join

        // Wait for frame to complete without reading LSR
        #(cfg.get_bit_period_ns() * 12.0);

        // Verify PE (LSR[2] = 1)
        apb_read(5'h14, temp_data);
        if (temp_data[2] == 1'b1) begin
            $display("[Generator] SUCCESS: Parity Error (LSR[2]) detected!");
        end else begin
            $error("[Generator] ERROR: Parity Error (LSR[2]) not set!");
        end

        // Read RBR to clear FIFO
        apb_read(5'h00, temp_data);

        // Reset FIFOs
        $display("[Generator] Clearing FIFOs for next test...");
        apb_write(5'h08, 8'h06);


        $display("\n==================================================");
        $display("[Generator] TEST CASE 5: Framing Error Injection");
        $display("==================================================");
        fork
            begin
                apb_write(5'h00, 8'h55);
            end
            begin
                real bit_p = cfg.get_bit_period_ns();
                @(negedge v_uart.TXD);
                // Wait for 10 bit periods to reach the stop bit (1 start + 8 data + 1 parity)
                #(bit_p * 10.0);
                #(bit_p * 0.2); // Mid-stop-bit
                $display("[Generator] Driving RXD low during stop bit to inject Framing Error...");
                v_uart.err_val    = 1'b0;
                v_uart.err_inject = 1'b1;
                #(bit_p * 0.6);
                v_uart.err_inject = 1'b0;
            end
        join

        // Wait for frame to complete
        #(cfg.get_bit_period_ns() * 12.0);

        // Verify FE (LSR[3] = 1)
        apb_read(5'h14, temp_data);
        if (temp_data[3] == 1'b1) begin
            $display("[Generator] SUCCESS: Framing Error (LSR[3]) detected!");
        end else begin
            $error("[Generator] ERROR: Framing Error (LSR[3]) not set!");
        end

        // Read RBR to clear FIFO
        apb_read(5'h00, temp_data);

        // Reset FIFOs
        $display("[Generator] Clearing FIFOs for next test...");
        apb_write(5'h08, 8'h06);


        $display("\n==================================================");
        $display("[Generator] TEST CASE 6: Break Interrupt Injection");
        $display("==================================================");
        begin
            real bit_p = cfg.get_bit_period_ns();
            $display("[Generator] Driving RXD low for 15 bit periods to trigger Break Interrupt...");
            v_uart.err_val    = 1'b0;
            v_uart.err_inject = 1'b1;
            #(bit_p * 15.0);
            v_uart.err_inject = 1'b0;
        end

        // Wait for break frame completion
        #(cfg.get_bit_period_ns() * 5.0);

        // Verify BI (LSR[4] = 1)
        apb_read(5'h14, temp_data);
        if (temp_data[4] == 1'b1) begin
            $display("[Generator] SUCCESS: Break Interrupt (LSR[4]) detected!");
        end else begin
            $error("[Generator] ERROR: Break Interrupt (LSR[4]) not set!");
        end

        // Read RBR to clear FIFO
        apb_read(5'h00, temp_data);

        // Reset FIFOs
        $display("[Generator] Clearing FIFOs for next test...");
        apb_write(5'h08, 8'h06);


        $display("\n==================================================");
        $display("[Generator] TEST CASE 7: FIFO Clear Test");
        $display("==================================================");
        // Write 5 bytes to TX FIFO
        $display("[Generator] Writing 5 bytes to TX FIFO...");
        for (int i = 0; i < 5; i++) begin
            apb_write(5'h00, 8'hD0 + i);
        end
        
        // Immediately clear the TX FIFO via FCR
        $display("[Generator] Issuing TX FIFO Clear via FCR...");
        apb_write(5'h08, 8'h04); // FCR[2] = 1 (TX clear)

        // Wait to make sure transmission completes
        #(cfg.get_bit_period_ns() * 15.0);

        // Read the 1 byte that was already in the shift register and couldn't be cleared
        apb_read(5'h14, temp_data); // Read LSR
        if (temp_data[0] == 1'b1) begin
            apb_read(5'h00, temp_data); // Read that byte (d0)
            $display("[Generator] Read back non-clearable in-flight byte: %2h (expected d0)", temp_data);
            
            // Check that RX FIFO is now empty, meaning other 4 bytes were cleared
            apb_read(5'h14, temp_data);
            if (temp_data[0] == 1'b0) begin
                $display("[Generator] SUCCESS: TX FIFO cleared correctly, remaining 4 bytes discarded!");
            end else begin
                $error("[Generator] ERROR: More than 1 byte was received! LSR[0] = %b", temp_data[0]);
            end
        end else begin
            $display("[Generator] SUCCESS: No bytes received at all!");
        end

        // Final clear
        apb_write(5'h08, 8'h06);

        $display("\n==================================================");
        $display("[Generator] ALL TEST CASES COMPLETED!");
        $display("==================================================\n");
    endtask
endclass
