library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package array_types_pkg is
    type byte_array is array (0 to 6) of std_logic_vector(7 downto 0);
end package array_types_pkg;

package body array_types_pkg is
end package body array_types_pkg;

--Register_coeff

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.array_types_pkg.all;

entity Register_coeff is
    port(
        i_clk           : in std_logic;
        i_rst           : in std_logic;
        i_mem_data      : in std_logic_vector(7 downto 0);
        i_en_latch      : in std_logic; 
        i_filter_select : in std_logic; 
        coeffs          : out byte_array
    );
end Register_coeff;

architecture Behavioral of Register_coeff is
    signal coeff_regs     : byte_array := (others => (others => '0'));
    signal read_counter   : natural range 0 to 14 := 0;
    signal write_counter  : natural range 0 to 7  := 0;
    signal last_en        : std_logic := '0';
begin

    process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            coeff_regs    <= (others => (others => '0'));
            read_counter  <= 0;
            write_counter <= 0;
            last_en       <= '0';
        elsif rising_edge(i_clk) then
            last_en <= i_en_latch;           
            if i_en_latch = '1' and last_en = '0' then
                read_counter  <= 0;
                write_counter <= 0;
            end if;
            if i_en_latch = '1' then                
                if i_filter_select = '0' and read_counter < 7 then
                    coeff_regs(write_counter) <= i_mem_data;
                    write_counter <= write_counter + 1;                
                elsif i_filter_select = '1' and read_counter >= 7 and read_counter < 14 then
                    coeff_regs(write_counter) <= i_mem_data;
                    write_counter <= write_counter + 1;
                end if;                              
                if read_counter < 14 then
                    read_counter <= read_counter + 1;
                end if;
            end if;
        end if;
    end process;
    
    coeffs <= coeff_regs;

end architecture Behavioral;

--Shift_register

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.array_types_pkg.all;

entity Shift_register is
    port(
        i_clk       : in std_logic;
        i_rst       : in std_logic;
        i_en_latch  : in std_logic; 
        i_flush     : in std_logic; 
        i_mem_data  : in std_logic_vector(7 downto 0);
        words       : out byte_array
    );
end Shift_register;

architecture Behavioral of Shift_register is
    signal temp : byte_array := (others => (others => '0'));
begin
    process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            temp <= (others => (others => '0'));
        elsif rising_edge(i_clk) then
            if i_en_latch = '1' or i_flush = '1' then
                temp(0 to 5) <= temp(1 to 6);
            end if;
            if i_en_latch = '1' then
                temp(6) <= i_mem_data;
            elsif i_flush = '1' then
                temp(6) <= (others => '0'); 
            end if;
        end if;
    end process;

    words <= temp;
end architecture Behavioral;

--filter

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.array_types_pkg.all;

entity filter is
    port(
        i_clk           : in  std_logic;
        i_rst           : in  std_logic;
        o_filter_select : in  std_logic;
        coeffs          : in  byte_array;
        words           : in  byte_array;
        temp            : out std_logic_vector(19 downto 0)
    );
end entity filter;

architecture filter_arch of filter is
    signal result : signed(19 downto 0);
begin
    process(i_clk, i_rst)
        variable temp_sum : signed(19 downto 0);
        variable mult_res : signed(15 downto 0);
    begin
        if i_rst = '1' then
            result <= (others => '0');
        elsif rising_edge(i_clk) then
            temp_sum := (others => '0');
            
            if o_filter_select = '0' then               
            for i in 1 to 5 loop
                    mult_res := signed(coeffs(i)) * signed(words(i));
                    temp_sum := temp_sum + mult_res;
                end loop;
            else           
                for i in 0 to 6 loop
                    mult_res := signed(coeffs(i)) * signed(words(i));
                    temp_sum := temp_sum + mult_res;
                end loop;
            end if;
            
            result <= temp_sum;
        end if;
    end process;

    temp <= std_logic_vector(result);
end architecture filter_arch;

--Normalizer

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Normalizer is
    port(
        i_clk           : in  std_logic;
        i_rst           : in  std_logic;
        o_filter_select : in  std_logic;
        temp            : in  std_logic_vector(19 downto 0);
        o_mem_data      : out std_logic_vector(7 downto 0)
    );
end entity Normalizer;

architecture Normalizer_arch of Normalizer is
begin
    process(i_clk, i_rst)
        variable temp_val : signed(19 downto 0);
        variable x1, x2, x3, x4: signed(19 downto 0);
        variable sum_val  : signed(19 downto 0);
    begin
        if i_rst = '1' then
            o_mem_data <= (others => '0');
        elsif rising_edge(i_clk) then
            temp_val := signed(temp);

            if o_filter_select = '0' then
                x1 := shift_right(temp_val, 4); 
                x2 := shift_right(temp_val, 6);
                x3 := shift_right(temp_val, 8); 
                x4 := shift_right(temp_val, 10);
                if temp_val < 0 then
                    x1 := x1 + 1; x2 := x2 + 1; x3 := x3 + 1; x4 := x4 + 1;
                end if;
                sum_val := x1 + x2 + x3 + x4;
            else
                x1 := shift_right(temp_val, 6); x2 := shift_right(temp_val, 10);
                if temp_val < 0 then
                    x1 := x1 + 1; x2 := x2 + 1;
                end if;
                sum_val := x1 + x2;
            end if;
            
            if sum_val > 127 then
                o_mem_data <= std_logic_vector(to_signed(127, 8));
            elsif sum_val < -128 then
                o_mem_data <= std_logic_vector(to_signed(-128, 8));
            else
                o_mem_data <= std_logic_vector(resize(sum_val, 8));
            end if;
        end if;
    end process;
end architecture Normalizer_arch;

--Address_Manager

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Address_Manager is
    port(
        i_clk         : in  std_logic;
        i_rst         : in  std_logic;
        i_start       : in  std_logic;
        i_add         : in  std_logic_vector(15 downto 0);
        i_k_stable    : in  std_logic_vector(15 downto 0); 
        i_increment_w : in  std_logic;
        i_increment_r : in  std_logic;
        i_mux_select  : in  std_logic;
        o_mem_addr    : out std_logic_vector(15 downto 0)
    );
end entity Address_Manager;

architecture Behavioral of Address_Manager is
    signal w_addr_ptr  : unsigned(15 downto 0) := (others => '0');
    signal r_addr_ptr  : unsigned(15 downto 0) := (others => '0');
    signal init_r_done : std_logic := '0';
    signal last_start  : std_logic := '0'; 
begin

    process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            w_addr_ptr  <= (others => '0');
            r_addr_ptr  <= (others => '0');
            init_r_done <= '0';
            last_start  <= '0';
        elsif rising_edge(i_clk) then
            
            last_start <= i_start;

            if (i_start = '1' and last_start = '0') then
                w_addr_ptr <= unsigned(i_add);
            elsif i_increment_w = '1' then
                w_addr_ptr <= w_addr_ptr + 1;
            end if;

            if (i_start = '1' and last_start = '0') then
                init_r_done <= '0';
            end if;
            
            if init_r_done = '0' and i_k_stable /= X"0000" then
                r_addr_ptr  <= unsigned(i_add) + 17 + unsigned(i_k_stable);
                init_r_done <= '1';
            elsif i_increment_r = '1' then
                r_addr_ptr <= r_addr_ptr + 1;
            end if;
            
        end if;
    end process;
    
    o_mem_addr <= std_logic_vector(r_addr_ptr) when i_mux_select = '1' else
                  std_logic_vector(w_addr_ptr);
end architecture Behavioral;

--fsm

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fsm is
    Port (
        i_clk             : in  std_logic;
        i_rst             : in  std_logic;
        i_start           : in  std_logic;
        i_mem_data        : in  std_logic_vector(7 downto 0);
        o_k_reg_stable    : out std_logic_vector(15 downto 0);
        o_filter_select   : out std_logic;
        o_en1             : out std_logic;
        o_en2             : out std_logic;
        o_increment_R     : out std_logic;
        o_increment_W     : out std_logic;
        o_mux_select      : out std_logic;
        o_done            : out std_logic;
        o_mem_we          : out std_logic;
        o_mem_en          : out std_logic;
        o_flush           : out std_logic;
        o_datapath_reset  : out std_logic
    );
end fsm;

architecture fsm_arch of fsm is
    type state is (
        IDLE, REQ_K1, WAIT_K1, REQ_K2, WAIT_K2, LATCH_K,
        REQ_S, WAIT_S, REQ_C, WAIT_C,
        READ_DATA, LATCH_AND_WRITE,
        DONE
    );
    signal curr_state       : state   := IDLE;
    signal internal_counter : natural := 0;
    signal k_reg            : natural := 0;
    signal k1_byte_reg      : unsigned(7 downto 0) := (others => '0');
    signal filter_selected  : std_logic := '0';

begin
    process(i_clk, i_rst)
        variable terminal_count : natural;
    begin
        if i_rst = '1' then
            curr_state <= IDLE; internal_counter <= 0; k_reg <= 0;
            k1_byte_reg <= (others => '0'); filter_selected <= '0';
        elsif rising_edge(i_clk) then
            case curr_state is
                when IDLE =>
                    if i_start = '1' then
                        curr_state <= REQ_K1; internal_counter <= 0; k_reg <= 0;
                        k1_byte_reg <= (others => '0'); filter_selected <= '0';
                    end if;
                when REQ_K1 => curr_state <= WAIT_K1;
                when WAIT_K1 => k1_byte_reg <= unsigned(i_mem_data); curr_state <= REQ_K2;
                when REQ_K2 => curr_state <= WAIT_K2;
                when WAIT_K2 => curr_state <= LATCH_K;
                when LATCH_K => k_reg <= to_integer(k1_byte_reg & unsigned(i_mem_data)); curr_state <= REQ_S;
                when REQ_S => curr_state <= WAIT_S;
                when WAIT_S =>
                    if i_mem_data(0) = '0' then filter_selected <= '0'; else filter_selected <= '1'; end if;
                    curr_state <= REQ_C; internal_counter <= 0;
                when REQ_C => curr_state <= WAIT_C;
                when WAIT_C =>
                    if internal_counter = 13 then
                        curr_state <= READ_DATA; internal_counter <= 0;
                    else
                        curr_state <= REQ_C; internal_counter <= internal_counter + 1;
                    end if;
                when READ_DATA =>
                    curr_state <= LATCH_AND_WRITE; internal_counter <= internal_counter + 1;
                when LATCH_AND_WRITE =>
                    terminal_count := k_reg + 6;
                    if internal_counter = terminal_count then
                        curr_state <= DONE;
                    else
                        if internal_counter < k_reg then
                            curr_state <= READ_DATA;
                        else
                            curr_state <= LATCH_AND_WRITE;
                            internal_counter <= internal_counter + 1;
                        end if;
                    end if;
                when DONE =>
                    if i_start = '0' then curr_state <= IDLE; end if;
                when others => curr_state <= IDLE;
            end case;
        end if;
    end process;

    process(curr_state, internal_counter, k_reg, filter_selected, i_start)
        variable is_stutter_cycle : boolean;
    begin
        o_mem_we <= '0'; o_mem_en <= '0'; o_done <= '0'; o_en1 <= '0'; o_en2 <= '0';
        o_increment_R <= '0'; o_increment_W <= '0'; o_mux_select <= '0'; o_flush <= '0';
        o_datapath_reset <= '0';
        o_filter_select <= filter_selected;
        o_k_reg_stable <= std_logic_vector(to_unsigned(k_reg, 16));

        case curr_state is
            when IDLE =>
                if i_start = '1' then o_datapath_reset <= '1'; end if;
            when REQ_K1 | REQ_K2 | REQ_S | REQ_C =>
                o_mem_en <= '1'; o_increment_W <= '1';
            when WAIT_C => 
                o_en1 <= '1';
            when READ_DATA =>
                o_mem_en <= '1'; o_increment_W <= '1';
            when LATCH_AND_WRITE =>
                if internal_counter <= k_reg then o_en2 <= '1'; else o_flush <= '1'; end if;
                is_stutter_cycle := (internal_counter = k_reg + 1);             
                if internal_counter >= 6 then
                    if is_stutter_cycle then
                        o_mem_we <= '0'; o_increment_R <= '0'; 
                    else
                        o_mem_en <= '1'; o_mem_we <= '1'; o_increment_R <= '1'; o_mux_select <= '1';
                    end if;
                end if;       
            when DONE =>
                o_done <= '1';  
            when others => null;
        end case;
    end process;
end fsm_arch;

--project_reti_logiche

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.array_types_pkg.all;

entity project_reti_logiche is
    port (
        i_clk      : in  std_logic;
        i_rst      : in  std_logic;
        i_start    : in  std_logic;
        i_add      : in  std_logic_vector(15 downto 0);
        o_done     : out std_logic;
        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in  std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we   : out std_logic;
        o_mem_en   : out std_logic
    );
end project_reti_logiche;

architecture structural of project_reti_logiche is

    signal s_filter_select, s_en1, s_en2, s_en3, s_increment_R, s_increment_W, s_mux_select : std_logic;
    signal s_k_stable               : std_logic_vector(15 downto 0);
    signal s_coeffs                 : byte_array;
    signal s_words_window           : byte_array;
    signal s_filter_out_temp        : std_logic_vector(19 downto 0);
    signal s_normalizer_out         : std_logic_vector(7 downto 0);
    signal s_flush_pipeline         : std_logic;
    signal s_datapath_reset         : std_logic;
    signal s_datapath_rst_combined  : std_logic;

begin
    port_fsm : entity work.fsm
        port map (
            i_clk            => i_clk,
            i_rst            => i_rst,
            i_start          => i_start,
            i_mem_data       => i_mem_data,
            o_k_reg_stable   => s_k_stable,
            o_filter_select  => s_filter_select,
            o_en1            => s_en1,
            o_en2            => s_en2,
            o_increment_R    => s_increment_R,
            o_increment_W    => s_increment_W,
            o_mux_select     => s_mux_select,
            o_done           => o_done,
            o_mem_we         => o_mem_we,
            o_mem_en         => o_mem_en,
            o_flush          => s_flush_pipeline,
            o_datapath_reset => s_datapath_reset 
        );

    port_addr_manager : entity work.Address_Manager
        port map(
            i_clk         => i_clk,
            i_rst         => i_rst,
            i_add         => i_add,
            i_start       => i_start,
            i_k_stable    => s_k_stable,
            i_increment_w => s_increment_W,
            i_increment_r => s_increment_R,
            i_mux_select  => s_mux_select,
            o_mem_addr    => o_mem_addr
        );

    s_datapath_rst_combined <= i_rst or s_datapath_reset;

    port_register_coeff : entity work.Register_coeff 
        port map (
            i_clk           => i_clk, 
            i_rst           => s_datapath_rst_combined, 
            i_mem_data      => i_mem_data, 
            i_en_latch      => s_en1, 
            i_filter_select => s_filter_select, 
            coeffs          => s_coeffs
         );
             
    port_shift_register : entity work.Shift_register
        port map (
            i_clk       => i_clk,
            i_rst       => s_datapath_rst_combined,
            i_en_latch  => s_en2,
            i_flush     => s_flush_pipeline,
            i_mem_data  => i_mem_data,
            words       => s_words_window
        );
        
    port_filter : entity work.filter 
        port map (
            i_clk           => i_clk, 
            i_rst           => i_rst,
            o_filter_select => s_filter_select, 
            coeffs          => s_coeffs, 
            words           => s_words_window, 
            temp            => s_filter_out_temp
         );
         
    port_normalizer : entity work.Normalizer 
        port map (
            i_clk           => i_clk, 
            i_rst           => i_rst, 
            o_filter_select => s_filter_select, 
            temp            => s_filter_out_temp, 
            o_mem_data      => s_normalizer_out
          );

    o_mem_data <= s_normalizer_out;

end architecture structural;