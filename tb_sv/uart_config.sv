class uart_config;
    int divisor = 4;
    int wls = 8;
    int pen = 0;
    int eps = 0;
    int stb = 1;
    
    function real get_bit_period_ns();
        return 320.0 * divisor;
    endfunction
endclass
