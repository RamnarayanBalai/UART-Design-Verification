class apb_trans;
    rand bit [4:0]  addr;
    rand bit [31:0] data;
    rand bit        write;

    constraint addr_c {
        addr inside {5'h00, 5'h04, 5'h08, 5'h0C, 5'h14, 5'h1C};
    }
    
    constraint data_c {
        data[31:8] == 0;
    }

    function void display(string prefix = "");
        $display("[%s] Address=%2h Write=%b Data=%2h", prefix, addr, write, data[7:0]);
    endfunction
endclass
