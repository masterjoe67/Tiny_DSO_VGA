----------------------------------------------------------------------------------
-- Company:         M.J.E. (Digital Signal Electronics)
-- Engineer:        Giovanni Legati
-- 
-- Create Date:     16.03.2026
-- Design Name:     Zoe DSO - FPGA Core
-- Module Name:     Top_Main - RTL
-- Project Name:    Zoe Oscilloscope Project
-- Target Devices:  Intel Cyclone IV E
-- Tool Versions:   Quartus Prime 22.1+
-- 
-- Description: 
--    Top-level module for the Zoe DSO. Handles ADC clock distribution via 
--    ALTDDIO_OUT and high-speed data acquisition.
--
-- Author:     Giovanni Legati M.J.E.
-- Mail:  masterjoe67@hotmail.it
-- Revision:
--    Revision 1.8 - Initial release with ALTDDIO clock stability fix.
-- 
-- Additional Comments:
--    This code is part of the Zoe DSO project. The clock distribution 
--    logic has been enhanced to reduce jitter on ADC_A_CK and ADC_B_CK.
--
----------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all; 
use IEEE.NUMERIC_STD.ALL;
LIBRARY work;

ENTITY Tiny_DSO_VGA_top IS 
	PORT
	(
		CLOCK_50 :  IN  STD_LOGIC;
		RX :  IN  STD_LOGIC;
		
		KEY :  IN  STD_LOGIC_VECTOR(0 TO 0);
		KEY_ROWS :  IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		KEY_COLS :  OUT  STD_LOGIC_VECTOR(2 DOWNTO 0);
		LED :  INOUT  STD_LOGIC_VECTOR(7 DOWNTO 0);
		porta :  INOUT  STD_LOGIC_VECTOR(3 DOWNTO 0);

		TX :  OUT  STD_LOGIC;
			-- TFT SPI
		tft_sclk    	: out std_logic;
		tft_mosi    	: out std_logic;
		tft_cs      	: out std_logic;
		tft_dc      	: out std_logic;
		tft_rst     	: out std_logic;
		tft_backlight	: out std_logic;
		
			-- SMART ENCODER
		ENC_TBASE_A 	 :  IN  STD_LOGIC;
		ENC_TBASE_B 	 :  IN  STD_LOGIC;
		ENC_CH_1_POS_A :  IN  STD_LOGIC;
		ENC_CH_1_POS_B :  IN  STD_LOGIC;
		ENC_CH_1_POS_K :  IN  STD_LOGIC;
		ENC_CH_1_GAIN_A :  IN  STD_LOGIC;
		ENC_CH_1_GAIN_B :  IN  STD_LOGIC;
		ENC_CH_2_POS_A :  IN  STD_LOGIC;
		ENC_CH_2_POS_B :  IN  STD_LOGIC;
		ENC_CH_2_POS_K :  IN  STD_LOGIC;
		ENC_CH_2_GAIN_A :  IN  STD_LOGIC;
		ENC_CH_2_GAIN_B :  IN  STD_LOGIC;		
		ENC_TRIG_POS_A :  IN  STD_LOGIC;
		ENC_TRIG_POS_B :  IN  STD_LOGIC;
		ENC_TRIG_POS_K :  IN  STD_LOGIC;
		ENC_PAN_POS_A :  IN  STD_LOGIC;
		ENC_PAN_POS_B :  IN  STD_LOGIC;
		ENC_PAN_POS_K :  IN  STD_LOGIC;
		
		-- Interfaccia Modulo ADC Canale A
	  ADC_A           : in  std_logic_vector(11 downto 0); -- A1..12
	  ADC_A_CK         : out std_logic;                     -- Clock A
	  ADC_A_OR         : in  std_logic;                     -- Out of Range A
	  
	  -- Interfaccia Modulo ADC Canale B
	  ADC_B           : in  std_logic_vector(11 downto 0); -- B1..12
	  ADC_B_CK         : out std_logic;                     -- Clock B
	  ADC_B_OR         : in  std_logic;                     -- Out of Range B
	  
	  -- Interfaccia SDRAM
	  	DRAM_DQ :  INOUT  unsigned(15 DOWNTO 0);
		DRAM_CLK :  OUT  STD_LOGIC;
		DRAM_CKE :  OUT  STD_LOGIC;
		DRAM_CS_N :  OUT  STD_LOGIC;
		DRAM_RAS_N :  OUT  STD_LOGIC;
		DRAM_CAS_N :  OUT  STD_LOGIC;
		DRAM_WE_N :  OUT  STD_LOGIC;
		DRAM_ADDR :  OUT  unsigned(12 DOWNTO 0);
		DRAM_BA :  OUT  STD_LOGIC_VECTOR(1 DOWNTO 0);
		DRAM_DQM :  OUT  STD_LOGIC_VECTOR(1 DOWNTO 0);
		
	 -- Interfaccia VGA
	 	VGAR0 :  OUT  STD_LOGIC;
		VGAR1 :  OUT  STD_LOGIC;
		VGAR2 :  OUT  STD_LOGIC;
		VGAG0 :  OUT  STD_LOGIC;
		VGAG1 :  OUT  STD_LOGIC;
		VGAG2 :  OUT  STD_LOGIC;
		VGAB0 :  OUT  STD_LOGIC;
		VGAB1 :  OUT  STD_LOGIC;
		VGAB2 :  OUT  STD_LOGIC;
		VGAVS :  OUT  STD_LOGIC;
		VGAHS :  OUT  STD_LOGIC
		

		

		
	);
END Tiny_DSO_VGA_top;

ARCHITECTURE rtl OF Tiny_DSO_VGA_top IS 

COMPONENT top_avr_core_v8 PORT(
	nrst   : in    std_logic;
	clk    : in    std_logic;
	clk_spi : IN STD_LOGIC;
	clk_sync 	: in    std_logic;
	clk_vga  	: in    std_logic;
	clk_pixel  	: in    std_logic;
	-- Port 
	porta  : inout std_logic_vector(7 downto 0);
	portb  : inout std_logic_vector(7 downto 0);

	-- UART 
	rxd    : in    std_logic;
	txd    : out   std_logic;
	-- TFT SPI
	tft_sclk    : out std_logic;
	tft_mosi    : out std_logic;
	tft_cs      : out std_logic;
	tft_dc      : out std_logic;
	tft_rst     : out std_logic;
	tft_backlight : out std_logic;
	-- External interrupts
	INTx   : in    std_logic_vector(7 downto 0); 
	INT0	 : in    std_logic;

	-- Interfaccia Modulo ADC Canale A
	DATA_A           : in  std_logic_vector(11 downto 0); -- A1..12
	ACK         : out std_logic;                     -- Clock A
	ORA         : in  std_logic;                     -- Out of Range A

	-- Interfaccia Modulo ADC Canale B
	DATA_B           : in  std_logic_vector(11 downto 0); -- B1..12
	BCK         : out std_logic;                     -- Clock B
	ORB         : in  std_logic;                     -- Out of Range B

	--keys		: in    std_logic_vector(7 downto 0);
	key_rows 		: in  std_logic_vector(4 downto 0); -- 5 INGRESSI (pull-up)
	key_cols 		: out std_logic_vector(2 downto 0); -- 3 USCITE

	--Encoder
	s_enc_a        : in  std_logic_vector(6 downto 0);
	s_enc_b        : in  std_logic_vector(6 downto 0);
	enc_keys_i     : in  std_logic_vector(3 downto 0);

	  -- VGA & SDRAM Physical Pins
	vga_hsync    : out std_logic;
	vga_vsync    : out std_logic;
	vga_rgb      : out std_logic_vector(8 downto 0);
	dram_clk     : out std_logic;
	dram_cke     : out std_logic;
	dram_cs_n    : out std_logic;
	dram_ras_n   : out std_logic;
	dram_cas_n   : out std_logic;
	dram_we_n    : out std_logic;
	dram_ba      : out std_logic_vector(1 downto 0);
	dram_addr    : out unsigned(12 downto 0);
	dram_dqm     : out std_logic_vector(1 downto 0);
	dram_dq      : inout unsigned(15 downto 0)
	
	
	
	
	
	);
END COMPONENT;


COMPONENT pll_master
	PORT(inclk0 : IN STD_LOGIC;
		 c0 : OUT STD_LOGIC;
		 c2 : OUT STD_LOGIC
	);
END COMPONENT;

COMPONENT PLL_VGA 
	PORT
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC; 
		c1		: OUT STD_LOGIC;
		c2		: OUT STD_LOGIC
	);
END COMPONENT;

COMPONENT clk_adc_buffer
	PORT
	(
		datain_h		: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		datain_l		: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
		outclock		: IN STD_LOGIC ;
		dataout		: OUT STD_LOGIC_VECTOR (1 DOWNTO 0)
	);
END COMPONENT;




SIGNAL	clk0 :  STD_LOGIC;
SIGNAL	clk_adc :  STD_LOGIC;
SIGNAL	clk_spi :  STD_LOGIC;
SIGNAL	clk_vga :  STD_LOGIC;
SIGNAL	clk_sync :  STD_LOGIC;
SIGNAL	clk_pixel :  STD_LOGIC;
SIGNAL	nrst :  STD_LOGIC;
SIGNAL	rxd :  STD_LOGIC;
SIGNAL	s_enc_a : std_logic_vector(6 downto 0);
SIGNAL	s_enc_b : std_logic_vector(6 downto 0);
SIGNAL	enc_keys_i : std_logic_vector(3 downto 0);
SIGNAL 	porta_int  : std_logic_vector(7 downto 0);

signal   vga_rgb_bus    : std_logic_vector(8 downto 0);



BEGIN 

-- Istanza del buffer DDIO per i clock degli ADC
clk_output_bridge : component clk_adc_buffer 
    port map (
        datain_h   => "11",              -- Entrambi i canali a '1' sul fronte alto
        datain_l   => "00",              -- Entrambi i canali a '0' sul fronte basso
        outclock   => clk0,  
        dataout(0) => ADC_A_CK,          -- Pin fisico per ADC A
        dataout(1) => ADC_B_CK           -- Pin fisico per ADC B
    );


b2v_inst : top_avr_core_v8
PORT MAP(nrst => nrst,
	clk => clk0,
	clk_spi => clk_spi,
	clk_sync 	=> clk_sync,
	clk_vga  	=> clk_vga,
	clk_pixel  	=> clk_pixel,
	rxd => rxd,
	key_rows => KEY_ROWS,
	key_cols => KEY_COLS,
	enc_keys_i => enc_keys_i,

	porta => porta_int,
	--portb => portb,
	txd => TX,

	-- TFT SPI
	tft_sclk    => tft_sclk,
	tft_mosi    => tft_mosi,
	tft_cs      => tft_cs,
	tft_dc      => tft_dc,
	tft_rst     => tft_rst,
	tft_backlight => tft_backlight,

	DATA_A        => ADC_A, -- A1..12
	ACK      => open,                     -- Clock A
	ORA      => ADC_A_OR,                 -- Out of Range A

	-- Interfaccia Modulo ADC Canale B
	DATA_B       => ADC_B, -- B1..12
	BCK     => open,                     -- Clock B
	ORB     => ADC_B_OR,                 -- Out of Range B


	INTx   => (others => '0'),
	INT0	  => '0',

	s_enc_a => s_enc_a,
	s_enc_b => s_enc_b,
	
    -- VGA & SDRAM Physical Pins
	vga_hsync    => VGAHS,
	vga_vsync    => VGAVS,
	vga_rgb      => vga_rgb_bus,
	dram_clk     => DRAM_CLK, 
	dram_cke     => DRAM_CKE,
	dram_cs_n    => DRAM_CS_N,
	dram_ras_n   => DRAM_RAS_N,
	dram_cas_n   => DRAM_CAS_N,
	dram_we_n    => DRAM_WE_N,
	dram_ba      => DRAM_BA,
	dram_addr    => DRAM_ADDR,
	dram_dqm     => DRAM_DQM,
	dram_dq      => DRAM_DQ
);



b2v_inst1 : pll_master
PORT MAP(
	inclk0 => CLOCK_50,
	c0 => clk0,
	c2 => clk_spi);
		 
pll_vga_inst : pll_vga
PORT MAP(
	inclk0 => CLOCK_50,
	c0 => clk_sync,
	c1 => clk_vga,
	c2 => clk_pixel
	);



s_enc_a(0) <= ENC_CH_1_POS_A;
s_enc_b(0) <= ENC_CH_1_POS_B;
enc_keys_i(0) <= ENC_CH_1_POS_K;

s_enc_a(1) <= ENC_CH_1_GAIN_A;
s_enc_b(1) <= ENC_CH_1_GAIN_B;

s_enc_a(2) <= ENC_CH_2_POS_A;
s_enc_b(2) <= ENC_CH_2_POS_B;
enc_keys_i(1) <= ENC_CH_2_POS_K;

s_enc_a(3) <= ENC_CH_2_GAIN_A;
s_enc_b(3) <= ENC_CH_2_GAIN_B;

s_enc_a(4) <= ENC_TBASE_A;
s_enc_b(4) <= ENC_TBASE_B;

s_enc_a(5) <= ENC_TRIG_POS_A;
s_enc_b(5) <= ENC_TRIG_POS_B;
enc_keys_i(2) <= ENC_TRIG_POS_K;

s_enc_a(6) <= ENC_PAN_POS_A;
s_enc_b(6) <= ENC_PAN_POS_B;
enc_keys_i(3) <= ENC_PAN_POS_K;




nrst <= KEY(0);
rxd <= RX;
LED <= porta_int;
porta <= porta_int(3 downto 0);

-- Mappatura Rosso (RED)
VGAR2 <= vga_rgb_bus(8); -- Bit più significativo (MSB)
VGAR1 <= vga_rgb_bus(7);
VGAR0 <= vga_rgb_bus(6); -- Bit meno significativo (LSB)

-- Mappatura Verde (GREEN)
VGAG2 <= vga_rgb_bus(5); -- MSB
VGAG1 <= vga_rgb_bus(4);
VGAG0 <= vga_rgb_bus(3); -- LSB

-- Mappatura Blu (BLUE)
VGAB2 <= vga_rgb_bus(2); -- MSB
VGAB1 <= vga_rgb_bus(1);
VGAB0 <= vga_rgb_bus(0); -- LSB

END rtl;

