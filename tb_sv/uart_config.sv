class uart_config;
    rand int divisor;
    rand int wls;
    rand int pen;
    rand int eps;
    rand int stb;

    constraint limits_c {
        divisor inside {[4:64]}; // Keep divisor reasonable for simulation speed
        wls     == 8;
        pen     == 1;
        eps     == 1;
        stb     == 1;
    }
    
    function real get_bit_period_ns();
        return 320.0 * divisor;
    endfunction
endclass
