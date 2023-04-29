-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Stefan Peknik <xpekni01@stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
  port (
    CLK   : in std_logic;  -- hodinovy signal
    RESET : in std_logic;  -- asynchronni reset procesoru
    EN    : in std_logic;  -- povoleni cinnosti procesoru
 
    -- synchronni pamet RAM
    DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
    DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
    DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
    DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
    DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
    -- vstupni port
    IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
    IN_VLD    : in std_logic;                      -- data platna
    IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
    -- vystupni port
    OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
    OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
    OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
  );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

--- CNT
signal cnt_reg : std_logic_vector(7 downto 0) := (others => '0');
signal cnt_inc : std_logic;
signal cnt_dec : std_logic;
--- CNT

--- PC
  signal pc_reg : std_logic_vector(11 downto 0) := (others => '0');
  signal pc_inc : std_logic;
  signal pc_dec : std_logic;
--- PC

--- PTR
  signal ptr_reg : std_logic_vector(11 downto 0) := (others => '0');
  signal ptr_inc : std_logic;
  signal ptr_dec : std_logic;
--- PTR

--- STATES
  type fsm_state is (
    s_start,
    s_fetch,
    s_decode,

    s_prog_inc,
    s_prog_dec,

    s_mem_inc,
    s_mem_inc_2,
    s_mem_dec,
    s_mem_dec_2,

    s_while_start,
    s_while_s_2,
    s_while_s_3,
    s_while_s_4,
    s_while_end,
    s_while_e_2,
    s_while_e_3,
    s_while_e_4,
    s_while_e_5,
    s_while_e_6,

    s_do_while_start,
    s_do_while_end,
    s_do_while_e_2,
    s_do_while_e_3,
    s_do_while_e_4,
    s_do_while_e_5,
    s_do_while_e_6,

    s_write,
    s_write_2,

    s_get,

    s_others,
    s_null
  );
  signal state   : fsm_state := s_start;
  signal n_state : fsm_state;
--- STATES

--- MX1
  signal mx1_sel : std_logic;
--- MX1

--- MX2
  signal mx2_sel : std_logic_vector(1 downto 0);
--- MX2


begin


--- CNT ---
  cnt: process (CLK, RESET, cnt_inc, cnt_dec) is
  begin
    if RESET = '1' then
      cnt_reg <= (others => '0');
    elsif rising_edge(CLK) then
      if cnt_inc = '1' then
        cnt_reg <= cnt_reg + 1;
      elsif cnt_dec = '1' then
        cnt_reg <= cnt_reg - 1;
      end if;
    end if; 
  end process;
--- CNT ---

--- PC ---
  pc: process (CLK, RESET, pc_inc, pc_dec) is
  begin
    if RESET = '1' then
      pc_reg <= (others => '0');
    elsif rising_edge(CLK) then
      if pc_inc = '1' then
        pc_reg <= pc_reg + 1;
      elsif pc_dec = '1' then
        pc_reg <= pc_reg - 1;
      end if;
    end if; 
  end process;
--- PC ---


--- PTR ---
  ptr: process (CLK, RESET, ptr_inc, ptr_dec) is
  begin
    if RESET = '1' then
      ptr_reg <= (others => '0');
    elsif rising_edge(CLK) then
      if ptr_inc = '1' then
        ptr_reg <= ptr_reg + 1;
      elsif ptr_dec = '1' then
        ptr_reg <= ptr_reg - 1;
      end if;
    end if;
  end process;
--- PTR ---

--- MX1 ---
  mx1: process (pc_reg, ptr_reg, mx1_sel) is
  begin
    case mx1_sel is
      when '0' =>
        DATA_ADDR <= "0" & pc_reg;
      when '1' =>
        DATA_ADDR <= "1" & ptr_reg;
      when others => NULL;
    end case;
  end process;
--- MX1 ---

--- MX2 ---
  mx2: process (mx2_sel, IN_DATA, DATA_RDATA) is
  begin
    case mx2_sel is
      when "10" =>
        DATA_WDATA <= DATA_RDATA - 1;
      when "01" =>
        DATA_WDATA <= DATA_RDATA + 1;
      when "11" =>
        DATA_WDATA <= IN_DATA;
      when others => NULL;
    end case;
  end process;
--- MX2 ---
  
--- FSM ---
  state_logic: process (CLK, RESET, EN) is
  begin
    if RESET = '1' then
      state <= s_start;
    elsif rising_edge(CLK) then
      if EN = '1' then
        state <= n_state;
      end if;
    end if;
  end process;

  fsm: process (state, OUT_BUSY, DATA_RDATA, IN_VLD) is
  begin
    -- init
    cnt_inc <= '0';
    cnt_dec <= '0';

    pc_inc <= '0';
    pc_dec <= '0';

    ptr_inc <= '0';
    ptr_dec <= '0';

    cnt_inc <= '0';
    cnt_dec <= '0';

    DATA_EN <= '0';
    IN_REQ <= '0';
    OUT_WE <= '0';
    DATA_RDWR <= '0';
    OUT_DATA <= DATA_RDATA;

    mx1_sel <= '0';
    mx2_sel <= "00";
    -- switch
    case state is
      when s_start =>
        n_state <= s_fetch;
      when s_fetch =>
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        n_state <= s_decode;
      when s_decode =>
        case DATA_RDATA is
          when X"3E" => -- >
            n_state <= s_prog_inc;
          when X"3C" => -- <
            n_state <= s_prog_dec;
          when X"2B" => -- +
            n_state <= s_mem_inc;
          when X"2D" => -- -
            n_state <= s_mem_dec;
          when X"5B" => -- [
            n_state <= s_while_start;
          when X"5D" => -- ]
            n_state <= s_while_end;
          when X"28" => -- (
            n_state <= s_do_while_start;
          when X"29" => -- )
            n_state <= s_do_while_end;
          when X"2E" => -- .
            n_state <= s_write;
          when X"2C" => -- ,
            n_state <= s_get;
          when X"00" => -- null
            n_state <= s_null;
          when others => -- other
            n_state <= s_others;
        end case;

      -- > 
      when s_prog_inc =>
        ptr_inc <= '1';
        pc_inc <= '1';
        n_state <= s_fetch;
      -- >

      -- <
      when s_prog_dec =>
        ptr_dec <= '1';
        pc_inc <= '1';
        n_state <= s_fetch;
      -- <  
      
      -- +
      when s_mem_inc =>
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        mx1_sel <= '1';
        n_state <= s_mem_inc_2;

      when s_mem_inc_2 =>
        DATA_EN <= '1';
        DATA_RDWR <= '1';
        mx2_sel <= "01";
        mx1_sel <= '1';
        pc_inc <= '1';
        n_state <= s_fetch;
      -- +
      
      -- -
      when s_mem_dec =>
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        mx1_sel <= '1';
        n_state <= s_mem_dec_2;

      when s_mem_dec_2 =>
        DATA_EN <= '1';
        DATA_RDWR <= '1';
        mx2_sel <= "10";
        mx1_sel <= '1';
        pc_inc <= '1';
        n_state <= s_fetch;
      -- -

      -- .
      when s_write =>
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        mx1_sel <= '1';
        if OUT_BUSY = '1' then
          n_state <= s_write;
        else
          n_state <= s_write_2;
        end if;
      
      when s_write_2 =>
        mx1_sel <= '1';
        OUT_WE <= '1';
        OUT_DATA <= DATA_RDATA;
        pc_inc <= '1';
        n_state <= s_fetch;
      -- .

      -- ,
      when s_get =>
        IN_REQ <= '1';
        DATA_EN <= '1';
        DATA_RDWR <= '1';
        if IN_VLD = '0' then
          n_state <= s_get;
        else
          mx1_sel <= '1';
          mx2_sel <= "11";
          pc_inc <= '1';
          n_state <= s_fetch;
        end if;
      -- ,

      -- [
      when s_while_start =>
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        pc_inc <= '1';
        mx1_sel <= '1';
        n_state <= s_while_s_2;
      
      when s_while_s_2 =>
        mx1_sel <= '1';
        if DATA_RDATA = "00000000" then
          cnt_inc <= '1';
          n_state <= s_while_s_3;
        else
          n_state <= s_fetch;
        end if;
      
      when s_while_s_3 =>
        if cnt_reg = "00000000" then
          n_state <= s_fetch;
        else
          mx1_sel <= '0';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          n_state <= s_while_s_4;
        end if;

      when s_while_s_4 =>
        if DATA_RDATA = X"5B" then
          cnt_inc <= '1';
        elsif DATA_RDATA = X"5D" then
          cnt_dec <= '1';
        elsif DATA_RDATA = X"28" then
          cnt_inc <= '1';
        elsif DATA_RDATA = X"29" then
          cnt_dec <= '1';
        end if;
        pc_inc <= '1';
        n_state <= s_while_s_3;
        
      -- [

      -- ]
      when s_while_end =>
        DATA_EN <= '1';
        mx1_sel <= '1';
        n_state <= s_while_e_2;

      when s_while_e_2 =>
        mx1_sel <= '1';
        if DATA_RDATA = "00000000" then
          pc_inc <= '1';
          n_state <= s_fetch;
        else
          DATA_EN <= '1';
          cnt_inc <= '1';
          pc_dec <= '1';
          n_state <= s_while_e_3;
        end if;
      
      when s_while_e_3 =>
        DATA_EN <= '1';
        if cnt_reg = "00000000" then
          n_state <= s_fetch;
        else
            DATA_EN <= '1';
            DATA_RDWR <= '0';
            mx1_sel <= '0';
            n_state <= s_while_e_4;
      end if;

      when s_while_e_4 =>
          if DATA_RDATA = X"5D" then
            cnt_inc <= '1';
          elsif DATA_RDATA = X"5B" then
            cnt_dec <= '1';
          elsif DATA_RDATA = X"29" then
            cnt_inc <= '1';
          elsif DATA_RDATA = X"28" then
            cnt_dec <= '1';
          end if;
          n_state <= s_while_e_5;
        

      when s_while_e_5 =>
        DATA_EN <= '1';
        if cnt_reg = "00000000" then
          pc_inc <= '1';
        else
          pc_dec <= '1';
        end if;
        n_state <= s_while_e_3;
      -- ]

      -- (
      when s_do_while_start =>
        pc_inc <= '1';
        n_state <= s_fetch;
      -- (

      -- )
      when s_do_while_end =>
        DATA_EN <= '1';
        mx1_sel <= '1';
        n_state <= s_do_while_e_2;

      when s_do_while_e_2 =>
        mx1_sel <= '1';
        if DATA_RDATA = "00000000" then
          pc_inc <= '1';
          n_state <= s_fetch;
        else
          DATA_EN <= '1';
          cnt_inc <= '1';
          pc_dec <= '1';
          n_state <= s_do_while_e_3;
        end if;

        when s_do_while_e_3 =>
        DATA_EN <= '1';
        if cnt_reg = "00000000" then
          n_state <= s_fetch;
        else
            DATA_EN <= '1';
            DATA_RDWR <= '0';
            mx1_sel <= '0';
            n_state <= s_while_e_4;
      end if;

      when s_do_while_e_4 =>
          if DATA_RDATA = X"5D" then
            cnt_inc <= '1';
          elsif DATA_RDATA = X"5B" then
            cnt_dec <= '1';
          elsif DATA_RDATA = X"29" then
            cnt_inc <= '1';
          elsif DATA_RDATA = X"28" then
            cnt_dec <= '1';
          end if;
          n_state <= s_while_e_5;
        

      when s_do_while_e_5 =>
        DATA_EN <= '1';
        if cnt_reg = "00000000" then
          pc_inc <= '1';
        else
          pc_dec <= '1';
        end if;
        n_state <= s_while_e_3;
      -- )


      when s_others =>
        pc_inc <= '1';
        n_state <= s_fetch;

      when s_null =>
        DATA_EN <= '0';
        n_state <= s_null;


      when others => NULL;
      
      end case;
  end process;

end behavioral;