library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.AVRuCPackage.all;
use WORK.AVR_uC_CompPack.all;

entity dso_video_subsystem is
    port (
        clk_cpu      : in std_logic;    -- 60.00 MHz
        clk_sync     : in std_logic;    -- 114.54 MHz
        clk_vga      : in std_logic;    -- 25.2 MHz
        clk_pixel    : in std_logic;    -- 114.54 MHz
        reset_n      : in std_logic;

        -- MMIO Interface
        iore         : in  std_logic;
        mmio_we      : in  std_logic;
        mmio_addr    : in  std_logic_vector(6 downto 0);
        mmio_rdata   : out std_logic_vector(7 downto 0);
        mmio_wdata   : in  std_logic_vector(7 downto 0);
        out_en       : out std_logic;
        
        -- RAM Interface (Bus Dati AVR)
        bram_ce      : in  std_logic;
        mem_ramadr   : in  std_logic_vector(15 downto 0);
        ramwe        : in  std_logic;
        data_in      : in  std_logic_vector(7 downto 0);
        data_out     : out std_logic_vector(7 downto 0);

        -- Feedback
        video_ready  : out std_logic;

        -- Physical Pins
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
end dso_video_subsystem;

architecture rtl of dso_video_subsystem is

    -- Costanti Indirizzi MMIO (Dal tuo pacchetto AVRuCPackage)
    -- Assicurati che siano coerenti con il tuo header C


    -- Registri AVR (60MHz)
    signal reg_x            : unsigned(9 downto 0) := (others => '0');
    signal reg_y            : unsigned(9 downto 0) := (others => '0');
    signal reg_data_low     : std_logic_vector(7 downto 0) := (others => '0');
    signal reg_data_high    : std_logic_vector(7 downto 0) := (others => '0');
    signal video_active_reg : std_logic := '1'; 
    signal scanline_reg     : std_logic := '1';
    
    -- Controllo Scrittura Diretta
    signal addr_direct      : unsigned(23 downto 0);
    signal direct_req       : std_logic := '0';
    signal direct_ack       : std_logic;

    -- Segnali VGA / SDRAM
    signal sdr_pixel_out    : unsigned(15 downto 0);
    signal sdr_col_wr_addr  : unsigned(9 downto 0);
    signal vga_row_req_addr : unsigned(9 downto 0);
    signal vga_col_req_addr : unsigned(9 downto 0);
    signal vga_bus_internal : unsigned(10 downto 0);
    signal sdr_load_req     : std_logic;
    signal sdr_load_ack     : std_logic;
    signal wren_sdr_to_ram2 : std_logic;
    signal ram2_q_vec       : std_logic_vector(15 downto 0);

begin

-- 1. Mappatura Indirizzo SDRAM (Allineata al Controller bit 20)
process(reg_x, reg_y)
    variable col_tmp : unsigned(9 downto 0);
begin
    if reg_x < 320 then
        -- BA1=0, BA0=0, Riga=Y, Colonna=X
        addr_direct <= "00" & "000" & reg_y & reg_x(8 downto 0);
    else
        -- BA1=1, BA0=0, Riga=Y, Colonna=X-320
        col_tmp := reg_x - 320; 
        -- Ora estraiamo i 9 bit dalla variabile col_tmp, non dall'operazione
        addr_direct <= "10" & "000" & reg_y & col_tmp(8 downto 0);
    end if;
end process;

    -- 2. Gestione Bus AVR & MMIO (60MHz)
process(clk_cpu, reset_n)
    begin
        if reset_n = '0' then
            direct_req <= '0';
            reg_x <= (others => '0');
            reg_y <= (others => '0');
            reg_data_low <= (others => '0');
            reg_data_high <= (others => '0');
				video_active_reg <= '1';
        elsif rising_edge(clk_cpu) then
				if mmio_we = '1' and mmio_addr = VGA_REG_CTRL then
                direct_req <= mmio_wdata(0);
                video_active_reg    <= mmio_wdata(1);
                scanline_reg        <= mmio_wdata(2);
            end if;
            -- Trigger scrittura: quando scrivi il byte alto (0x4055)
            if (ramwe = '1' and bram_ce = '1') then
                case mem_ramadr is
                    when x"5050" => reg_x(7 downto 0) <= unsigned(data_in);
                    when x"5051" => reg_x(9 downto 8) <= unsigned(data_in(1 downto 0));
                    when x"5052" => reg_y(7 downto 0) <= unsigned(data_in);
                    when x"5053" => reg_y(9 downto 8) <= unsigned(data_in(1 downto 0));
                    when x"5054" => reg_data_low <= data_in;
                    when x"5055" => 
                        reg_data_high <= data_in;
                        direct_req <= '1'; 
                    when others => null;
                end case;
            end if;

            if direct_ack = '1' then 
                direct_req <= '0';
            end if;
        end if;
    end process;

    -- 3. Feedback MMIO (Lettura Stato)
    process(mmio_addr, iore, direct_req, video_active_reg, scanline_reg)
    begin
        mmio_rdata <= (others => '0'); 
        out_en <= '0';
        if iore = '1' then
            case mmio_addr is
                when VGA_REG_CTRL =>
                    mmio_rdata <= "00000" & scanline_reg & video_active_reg & direct_req;
                    out_en <= '1';
                when VGA_FBK_REG =>
                    mmio_rdata <= "0000000" & direct_req;
                    out_en <= '1';
                when others => null;
            end case;
        end if;
    end process;

    -- Uscita dati verso il bus AVR (Se serve leggere qualcosa)
    data_out <= (others => '0'); 

    -- 4. Controller SDRAM (Direct Access)
-- 4. Controller SDRAM (Direct Access + VGA Load)
    sdram_ctrl : entity work.sdram
        generic map ( 
            page0 => 320, 
            page1 => 320 
        )
        port map (
            clk             => clk_pixel,
            
            -- Interfaccia Video (Verso VGA Engine)
            pixelOut        => sdr_pixel_out,
            rowLoadNr       => vga_row_req_addr,
            rowLoadReq      => sdr_load_req,
            rowLoadAck      => sdr_load_ack,
            colLoadNr       => sdr_col_wr_addr,
            wren_sdr        => wren_sdr_to_ram2,

            -- Interfaccia AVR (Dal Subsystem)
            addrDirect      => addr_direct,
            pixelDirectIn   => unsigned(reg_data_high) & unsigned(reg_data_low),
            directWriteReq  => direct_req,
            directAck       => direct_ack,

            -- Pin Fisici SD-RAM
            pMemClk         => dram_clk,
            pMemCke         => dram_cke,
            pMemCs_n        => dram_cs_n,
            pMemRas_n       => dram_ras_n,
            pMemCas_n       => dram_cas_n,
            pMemWe_n        => dram_we_n,
            pMemUdq         => dram_dqm(1),
            pMemLdq         => dram_dqm(0),
            pMemBa1         => dram_ba(1),
            pMemBa0         => dram_ba(0),
            pMemAdr         => dram_addr,
            pMemDat         => dram_dq
        );

    -- 5. RAM2 (Line Buffer per monitor)
    read_buffer : entity work.ram2
        port map (
            data => std_logic_vector(sdr_pixel_out), wraddress => std_logic_vector(sdr_col_wr_addr),
            wrclock => clk_sync, wren => wren_sdr_to_ram2, rdaddress => std_logic_vector(vga_col_req_addr),
            rdclock => clk_vga, q => ram2_q_vec
        );

    -- 6. VGA Engine
    vga_engine : entity work.vgaout
        port map (
            clock_vga => clk_vga, clock_dram => clk_pixel, video_active => video_active_reg,
            scanline => scanline_reg, pixel_in => unsigned(ram2_q_vec), load_req => sdr_load_req,
            load_ack => sdr_load_ack, row_number => vga_row_req_addr, col_number => vga_col_req_addr,
            vga_out => vga_bus_internal
        );

    vga_hsync <= std_logic(vga_bus_internal(1));
    vga_vsync <= std_logic(vga_bus_internal(0));
    vga_rgb   <= std_logic_vector(vga_bus_internal(10 downto 2));
    video_ready <= not direct_req;

end rtl;