class uart_config;
    rand int divisor;
    rand int wls;
    rand int pen;
    rand int eps;
    rand int stb;

    constraint limits_c {
        divisor inside {[4:64]}; // Keep divisor reasonable for simulation speed
        wls     inside {5, 6, 7, 8};
        pen     inside {0, 1};
        eps     inside {0, 1};
        stb     inside {1, 2};
    }
    
    function real get_bit_period_ns();
        return 320.0 * divisor;
    endfunction
endclass
