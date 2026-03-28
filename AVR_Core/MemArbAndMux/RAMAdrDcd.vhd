----------------------------------------------------------------------------------
-- Project:         Zoe DSO - AVR Soft Core
-- Engineer:        Giovanni Legati M.J.E.
-- 
-- Description:     VHDL implementation of the AVR Soft Core architecture.
--                  This module executes the main control logic for the Zoe 
--                  oscilloscope, managing UI, triggers, and data processing.
--
-- Original Author: Ruslan Lepetenok
-- Modified by:     Giovanni Legati M.J.E.
--
-- Revision:        16/03/2026
--
-- Module:          Address decoder
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

use WORK.MemAccessCtrlPack.all;

entity RAMAdrDcd is port(
                       ramadr    : in std_logic_vector(15 downto 0);
		                 ramre     : in std_logic;
		                 ramwe     : in std_logic;
		                 -- Memory mapped I/O i/f
		                 stb_IO	   : out std_logic;
		                 stb_IOmod : out std_logic_vector(CNumOfSlaves-1 downto 0);		
	                     -- Data memory i/f
		                 ram_we    : out std_logic;
		                 ram_ce    : out std_logic;
							  bram_ce   : out std_logic;
							  vga_bram_ce : out std_logic;
							  ram_sel   : out std_logic
		                );
end RAMAdrDcd;

architecture RTL of RAMAdrDcd is
    signal ram_sel_int   : std_logic;
    signal scope_sel_int : std_logic; 
    signal vga_sel_int   : std_logic; 
begin

-- 1. Area Video BRAM (640 pixel * 2 byte = 1280 byte)
-- Da 0x4100 a 0x45FF
vga_sel_int <= '1' when (ramadr >= x"4100" and ramadr <= x"45FF") else '0';
vga_bram_ce <= vga_sel_int;

-- 2. Area Registri Video / Scope (0x4000 - 0x40FF)
-- Qui ricadono i tuoi VIDEO_REG_X, Y, ecc. (0x4050...)
scope_sel_int <= '1' when (ramadr >= x"4000" and ramadr <= x"40FF") else '0';
bram_ce       <= scope_sel_int;

-- 3. Area RAM standard
-- La RAM risponde solo se NON siamo nelle aree speciali
ram_sel_int <= '1' when (ramadr(ramadr'high downto ramadr'high-CDRAMBaseAdr'high) = CDRAMBaseAdr) 
               and (vga_sel_int = '0') 
               and (scope_sel_int = '0') else '0';

-- Segnali di controllo
ram_sel <= ram_sel_int; 
ram_we  <= ram_sel_int and ramwe;   
ram_ce  <= ram_sel_int and (ramwe or ramre);

-- I/O Mapped (Inalterato)
stb_IO        <= '1' when (ramadr(15 downto 8) = x"00") else '0';
stb_IOmod(0)  <= '1' when ramadr(7 downto 4)=x"0" else '0';
stb_IOmod(1)  <= '1' when ramadr(7 downto 4)=x"1" else '0';

end RTL;


