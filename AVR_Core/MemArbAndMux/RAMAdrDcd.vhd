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

----------------------------------------------------------------------------------
-- Project:         Zoe DSO - AVR Soft Core
-- Engineer:        Giovanni Legati M.J.E.
-- 
-- Description:     VHDL Address Decoder - Spostamento I/O a 0x5000
--                  Evita conflitti con lo Stack Pointer (0x40FF)
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
                  stb_IO    : out std_logic;
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
    signal ram_sel_int    : std_logic;
    signal scope_sel_int  : std_logic; 
    signal vga_sel_int    : std_logic; 
begin

-- 1. Area Video BRAM (Spostata a 0x5100 - 0x55FF)
-- Lasciamo spazio dopo i registri di controllo
vga_sel_int <= '1' when (ramadr >= x"5100" and ramadr <= x"55FF") else '0';
vga_bram_ce <= vga_sel_int;

-- 2. Area Registri Hardware / Scope (Spostata a 0x5000 - 0x50FF)
-- Ora è ben lontana dallo stack (0x40FF)
scope_sel_int <= '1' when (ramadr >= x"5000" and ramadr <= x"50FF") else '0';
bram_ce        <= scope_sel_int;

-- 3. Area RAM standard (0x0100 - 0x40FF)
-- Risponde solo per la memoria fisica reale dell'AVR
-- e si disattiva se l'indirizzo punta alle zone speciali 0x5xxx
ram_sel_int <= '1' when (ramadr < x"4100") 
               and (vga_sel_int = '0') 
               and (scope_sel_int = '0') 
               and (ramadr >= x"0100") else '0';

-- Segnali di controllo
ram_sel <= ram_sel_int; 
ram_we  <= ram_sel_int and ramwe;   
ram_ce  <= ram_sel_int and (ramwe or ramre);

-- I/O Mapped (Inalterato per registri interni core)
stb_IO        <= '1' when (ramadr(15 downto 8) = x"00") else '0';
stb_IOmod(0)  <= '1' when ramadr(7 downto 4)=x"0" else '0';
stb_IOmod(1)  <= '1' when ramadr(7 downto 4)=x"1" else '0';

end RTL;

