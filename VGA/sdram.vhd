--library IEEE;
--use IEEE.std_logic_1164.all;
--use IEEE.numeric_std.all;
--
--entity sdram is
--    generic(
--        page0 : integer := 320;
--        page1 : integer := 320
--    );
--    port(
--        clk             : in std_logic; 
--        
--        -- Interfaccia Video (Verso RAM2 e VGA)
--        pixelOut        : out unsigned(15 downto 0);
--        rowLoadNr       : in unsigned(9 downto 0); 
--        colLoadNr       : buffer unsigned(9 downto 0); 
--        rowLoadReq      : in std_logic;
--        rowLoadAck      : out std_logic := '0';
--        wren_sdr        : out std_logic;
--
--        -- Interfaccia AVR Direct (NUOVA)
--        addrDirect      : in unsigned(23 downto 0); 
--        pixelDirectIn   : in unsigned(15 downto 0);
--        directWriteReq  : in std_logic;
--        directAck       : out std_logic := '0';
--        
--        -- Pin Fisici
--        pMemClk : out std_logic; pMemCke : out std_logic; pMemCs_n : out std_logic;
--        pMemRas_n : out std_logic; pMemCas_n : out std_logic; pMemWe_n : out std_logic;
--        pMemUdq : out std_logic; pMemLdq : out std_logic;
--        pMemBa1 : out std_logic; pMemBa0 : out std_logic;
--        pMemAdr : out unsigned(12 downto 0);
--        pMemDat : inout unsigned(15 downto 0)
--    );
--end sdram;
--
--architecture rtl of sdram is
--    signal SdrCmd : unsigned(3 downto 0);
--    signal SdrBa0_s, SdrBa1_s : std_logic;
--    signal SdrAdr_s : unsigned(12 downto 0);
--    signal SdrDat_s : unsigned(15 downto 0);
--
--    constant SdrCmd_pr : unsigned(3 downto 0) := "0010"; -- PRE
--    constant SdrCmd_re : unsigned(3 downto 0) := "0001"; -- REFRESH
--    constant SdrCmd_ms : unsigned(3 downto 0) := "0000"; -- MODE
--    constant SdrCmd_xx : unsigned(3 downto 0) := "0111"; -- NOP
--    constant SdrCmd_ac : unsigned(3 downto 0) := "0011"; -- ACT
--    constant SdrCmd_rd : unsigned(3 downto 0) := "0101"; -- READ
--    constant SdrCmd_wr : unsigned(3 downto 0) := "0100"; -- WRITE
--    constant SdrCmd_bs : unsigned(3 downto 0) := "0110"; -- BURST STOP
--
--    type typSdrRoutine is (SdrRoutine_Init, SdrRoutine_Idle, SdrRoutine_LoadRow, SdrRoutine_DirectWrite);
--    
--    signal curRow : unsigned(9 downto 0);
--	 signal sdr_write_active : std_logic := '0';
--
--begin
--    -- Mapping Fisico
--    pMemClk <= clk; 
--    pMemCke <= '1';
--    pMemCs_n <= SdrCmd(3); pMemRas_n <= SdrCmd(2); pMemCas_n <= SdrCmd(1); pMemWe_n <= SdrCmd(0);
--    pMemBa0 <= SdrBa0_s; pMemBa1 <= SdrBa1_s; pMemAdr <= SdrAdr_s; 
--    pMemUdq <= '0'; pMemLdq <= '0'; -- Gestiti internamente o fissi a 0 per 16-bit
--	 
--	 pMemDat <= SdrDat_s when sdr_write_active = '1' else (others => 'Z');
--
----    process(clk)
----        variable SdrRoutine : typSdrRoutine := SdrRoutine_Init;
----        variable SdrRoutineSeq : integer range 0 to 2048 := 0;
----        variable SdrAddress : unsigned(23 downto 0);
----    begin
----        if rising_edge(clk) then
----            -- Default State
----            SdrCmd <= SdrCmd_xx; 
----            SdrDat_s <= (others => 'Z');
----            rowLoadAck <= '0'; 
----            directAck <= '0'; 
----            wren_sdr <= '0';
----
----            case SdrRoutine is
----                
----                when SdrRoutine_Init =>
----                    if SdrRoutineSeq = 0 then 
----                        SdrCmd <= SdrCmd_pr; SdrAdr_s <= (others => '1'); SdrBa0_s <= '0'; SdrBa1_s <= '0';
----                    elsif SdrRoutineSeq = 4 or SdrRoutineSeq = 12 then 
----                        SdrCmd <= SdrCmd_re;
----                    elsif SdrRoutineSeq = 20 then 
----                        SdrCmd <= SdrCmd_ms; SdrAdr_s <= "0000" & "00" & "011" & "0" & "111"; -- CL3, Burst Full Page
----                    elsif SdrRoutineSeq = 23 then 
----                        SdrRoutine := SdrRoutine_Idle; 
----                    end if;
----                    SdrRoutineSeq := SdrRoutineSeq + 1;
----
----                when SdrRoutine_Idle =>
----                    SdrRoutineSeq := 0;
----                    if (rowLoadReq = '1') then
----                        SdrAddress(23 downto 19) := "00000";
----                        SdrAddress(18 downto 9) := rowLoadNr;
----                        curRow <= rowLoadNr;
----                        SdrAddress(8 downto 0) := (others => '0');
----                        SdrRoutine := SdrRoutine_LoadRow;
----                    elsif (directWriteReq = '1') then
----                        SdrAddress := addrDirect;
----                        SdrRoutine := SdrRoutine_DirectWrite;
----                    end if;
----
----                when SdrRoutine_DirectWrite =>
----                    case SdrRoutineSeq is
----                        when 0 => 
----                            SdrCmd <= SdrCmd_ac; -- Activate Row
----                            SdrBa0_s <= SdrAddress(22); SdrBa1_s <= SdrAddress(23); 
----                            SdrAdr_s <= SdrAddress(21 downto 9);
----                        
----                        when 2 => 
----                            SdrCmd <= SdrCmd_wr; -- Write Command
----                            SdrAdr_s(10) <= '1'; -- Auto-Precharge (Cruciale per chiudere la riga)
----                            SdrAdr_s(8 downto 0) <= SdrAddress(8 downto 0);
----                            SdrDat_s <= pixelDirectIn;
----                        
----                        when 3 => 
----                            SdrDat_s <= pixelDirectIn; -- Mantiene il dato stabile per un ciclo
----
----                        -- AGGIUNTI NOP DI STABILIZZAZIONE
----                        when 4 => 
----                            SdrDat_s <= (others => 'Z'); -- Mette il bus in alta impedenza
----                            SdrCmd <= SdrCmd_xx; -- Forza un NOP fisico
----                        
----                        when 5 => 
----                            SdrCmd <= SdrCmd_xx; -- Secondo NOP fisico di attesa
----
----                        when 6 => 
----                            directAck <= '1'; -- Alza l'ACK solo ora che la riga è chiusa
----
----                        when 7 => 
----                            SdrRoutine := SdrRoutine_Idle;
----                        
----                        when others => null;
----                    end case;
----                    SdrRoutineSeq := SdrRoutineSeq + 1;
----
----                when SdrRoutine_LoadRow =>
----                    -- BANCO 0 (Primi 320 pixel)
----                    if SdrRoutineSeq = 0 then
----                        SdrCmd <= SdrCmd_ac;
----                        SdrBa0_s <= SdrAddress(22); SdrBa1_s <= '0';
----                        SdrAdr_s <= SdrAddress(21 downto 9);
----                        colLoadNr <= (others => '0');
----                    elsif SdrRoutineSeq = 2 then
----                        SdrCmd <= SdrCmd_rd;
----                        SdrAdr_s(12 downto 9) <= "0010"; -- A10 low per no-auto-precharge
----                        SdrAdr_s(8 downto 0) <= SdrAddress(8 downto 0);
----                    elsif SdrRoutineSeq >= 7 and SdrRoutineSeq < 7 + page0 then
----                        pixelOut <= pMemDat;
----                        wren_sdr <= '1';
----                        colLoadNr <= colLoadNr + 1;
----                    elsif SdrRoutineSeq = 7 + page0 then
----                        SdrCmd <= SdrCmd_bs;
----								wren_sdr <= '0'; -- ASSICURATI che sia a 0 qui
----                        -- Setup per il secondo banco
----                        SdrAddress(23 downto 19) := "00000";
----                        SdrAddress(18 downto 9) := curRow;
----                        SdrAddress(8 downto 0) := (others => '0');
----                    
----                    -- BANCO 1 (Secondi 320 pixel)
----                    elsif SdrRoutineSeq = 9 + page0 then
----                        SdrCmd <= SdrCmd_ac;
----                        SdrBa0_s <= SdrAddress(22); SdrBa1_s <= '1'; -- Cambio banco qui!
----                        SdrAdr_s <= SdrAddress(21 downto 9);
----                        colLoadNr <= to_unsigned(page0, colLoadNr'length); -- Forza offset a 320
----                    elsif SdrRoutineSeq = 11 + page0 then
----                        SdrCmd <= SdrCmd_rd;
----                        SdrAdr_s(12 downto 9) <= "0010";
----                        SdrAdr_s(8 downto 0) <= SdrAddress(8 downto 0);
----                    elsif SdrRoutineSeq >= 16 + page0 and SdrRoutineSeq < 16 + page0 + page1 then
----                        pixelOut <= pMemDat;
----                        wren_sdr <= '1';
----                        colLoadNr <= colLoadNr + 1;
----                    elsif SdrRoutineSeq = 16 + page0 + page1 then
----                        SdrCmd <= SdrCmd_bs;
----                        rowLoadAck <= '1';
----                    elsif SdrRoutineSeq = 17 + page0 + page1 then
----                        SdrRoutine := SdrRoutine_Idle;
----                    end if;
----                    SdrRoutineSeq := SdrRoutineSeq + 1;
----
----            end case;
----        end if;
----    end process;
--
---- AGGIUNGI QUESTO SEGNALE NELLA SEZIONE ARCHITECTURE (sopra il begin)
---- signal sdr_write_active : std_logic := '0';
--
---- E FUORI DAL PROCESS, SOSTITUISCI IL MAPPING DI pMemDat CON QUESTO:
---- pMemDat <= SdrDat_s when sdr_write_active = '1' else (others => 'Z');
--
--process(clk)
--    variable SdrRoutine : typSdrRoutine := SdrRoutine_Init;
--    variable SdrRoutineSeq : integer range 0 to 2048 := 0;
--    variable SdrAddress : unsigned(23 downto 0);
--begin
--    if rising_edge(clk) then
--        -- Default State
--        SdrCmd <= SdrCmd_xx; 
--        rowLoadAck <= '0'; 
--        directAck <= '0'; 
--        wren_sdr <= '0';
--        
--        -- Forza il bus in alta impedenza di default (tramite il segnale di controllo)
--        sdr_write_active <= '0'; 
--
--        case SdrRoutine is
--            
--            when SdrRoutine_Init =>
--                if SdrRoutineSeq = 0 then 
--                    SdrCmd <= SdrCmd_pr; SdrAdr_s <= (others => '1'); SdrBa0_s <= '0'; SdrBa1_s <= '0';
--                elsif SdrRoutineSeq = 4 or SdrRoutineSeq = 12 then 
--                    SdrCmd <= SdrCmd_re;
--                elsif SdrRoutineSeq = 20 then 
----                    SdrCmd <= SdrCmd_ms; 
----						  SdrAdr_s <= "0000" & "00" & "011" & "0" & "111"; 
--						  -- Bit 9 = '1' (Single Write Mode)
--						 -- Bit 6-4 = "011" (CAS Latency 3)
--						 -- Bit 2-0 = "111" (Full Page Burst per la lettura)
--						 SdrCmd <= SdrCmd_ms; 
--						 SdrAdr_s <= "000" & '1' & "00" & "011" & "0" & "111";
--                elsif SdrRoutineSeq = 23 then 
--                    SdrRoutine := SdrRoutine_Idle; 
--                end if;
--                SdrRoutineSeq := SdrRoutineSeq + 1;
--
----            when SdrRoutine_Idle =>
----                SdrRoutineSeq := 0;
----                if (rowLoadReq = '1') then
----                    SdrAddress(23 downto 19) := "00000";
----                    SdrAddress(18 downto 9) := rowLoadNr;
----                    curRow <= rowLoadNr;
----                    SdrAddress(8 downto 0) := (others => '0');
----                    SdrRoutine := SdrRoutine_LoadRow;
----                elsif (directWriteReq = '1') then
----                    SdrAddress := addrDirect;
----                    SdrRoutine := SdrRoutine_DirectWrite;
----                end if;
--
--when SdrRoutine_Idle =>
--                    -- Aggiungiamo un piccolo ritardo forzato tra un'operazione e l'altra
--                    if SdrRoutineSeq < 4 then 
--                        SdrRoutineSeq := SdrRoutineSeq + 1;
--                    else
--                        if (rowLoadReq = '1') then
--                            SdrRoutineSeq := 0; -- Reset per la nuova routine
--                            SdrAddress(23 downto 19) := "00000";
--                            SdrAddress(18 downto 9) := rowLoadNr;
--                            curRow <= rowLoadNr;
--                            SdrAddress(8 downto 0) := (others => '0');
--                            SdrRoutine := SdrRoutine_LoadRow;
--                        elsif (directWriteReq = '1') then
--                            SdrRoutineSeq := 0; -- Reset per la nuova routine
--                            SdrAddress := addrDirect;
--                            SdrRoutine := SdrRoutine_DirectWrite;
--                        end if;
--                    end if;
--
----            when SdrRoutine_DirectWrite =>
----                case SdrRoutineSeq is
----                    when 0 => 
----                        SdrCmd <= SdrCmd_ac; 
----                        SdrBa0_s <= SdrAddress(22); SdrBa1_s <= SdrAddress(23); 
----                        SdrAdr_s <= SdrAddress(21 downto 9);
----                    
----                    when 2 => 
----    SdrCmd <= SdrCmd_wr; 
----    SdrAdr_s <= (others => '0'); -- Pulisce tutto l'indirizzo
----    SdrAdr_s(10) <= '1';         -- Attiva Auto-Precharge
----    SdrAdr_s(8 downto 0) <= SdrAddress(8 downto 0); -- Colonna
----    SdrDat_s <= pixelDirectIn;
----    sdr_write_active <= '1';
----                    
----                    when 3 => 
----                        SdrDat_s <= pixelDirectIn;
----                        sdr_write_active <= '1'; -- Mantieni il driver attivo
----
----                    when 4 => 
----                        -- Qui sdr_write_active va a 0 automaticamente (default state)
----                        -- Il bus pMemDat diventa 'Z' istantaneamente
----                        SdrCmd <= SdrCmd_xx; 
----                    
----                    when 5 => 
----                        SdrCmd <= SdrCmd_xx; -- NOP di sicurezza
----
----                    when 6 => 
----                        directAck <= '1'; -- Segnala fine all'AVR
----
----                    when 7 => 
----                        SdrRoutine := SdrRoutine_Idle;
----                    
----                    when others => null;
----                end case;
----                SdrRoutineSeq := SdrRoutineSeq + 1;
--
--when SdrRoutine_DirectWrite =>
--                    case SdrRoutineSeq is
--                        when 0 => 
--                            SdrCmd <= SdrCmd_ac; 
--                            SdrBa0_s <= SdrAddress(22); SdrBa1_s <= SdrAddress(23); 
--                            SdrAdr_s <= SdrAddress(21 downto 9);
--                        when 2 => 
--                            SdrCmd <= SdrCmd_wr; 
--                            SdrAdr_s(10) <= '1'; 
--                            SdrAdr_s(8 downto 0) <= SdrAddress(8 downto 0);
--                            SdrDat_s <= pixelDirectIn;
--                            sdr_write_active <= '1';
--                        when 3 => 
--                            SdrDat_s <= pixelDirectIn;
--                            sdr_write_active <= '1';
--                        when 4 => 
--                            sdr_write_active <= '0';
--                            SdrCmd <= SdrCmd_xx;
--                        when 5 to 8 => -- Aumentato il tempo di attesa (tRP)
--                            SdrCmd <= SdrCmd_xx;
--                        when 9 => 
--                            directAck <= '1'; -- ACK spostato più avanti
--                        when 10 => 
--                            SdrRoutine := SdrRoutine_Idle;
--                        when others => null;
--                    end case;
--                    SdrRoutineSeq := SdrRoutineSeq + 1;
--
--            when SdrRoutine_LoadRow =>
--                if SdrRoutineSeq = 0 then
--                    SdrCmd <= SdrCmd_ac;
--                    SdrBa0_s <= SdrAddress(22); SdrBa1_s <= '0';
--                    SdrAdr_s <= SdrAddress(21 downto 9);
--                    colLoadNr <= (others => '0');
--                elsif SdrRoutineSeq = 2 then
--                    SdrCmd <= SdrCmd_rd;
--                    SdrAdr_s(12 downto 9) <= "0010";
--                    SdrAdr_s(8 downto 0) <= SdrAddress(8 downto 0);
--                elsif SdrRoutineSeq >= 7 and SdrRoutineSeq < 7 + page0 then
--                    pixelOut <= pMemDat;
--                    wren_sdr <= '1';
--                    colLoadNr <= colLoadNr + 1;
--                elsif SdrRoutineSeq = 7 + page0 then
--                    SdrCmd <= SdrCmd_bs;
--                    wren_sdr <= '0'; 
--                    SdrAddress(23 downto 19) := "00000";
--                    SdrAddress(18 downto 9) := curRow;
--                    SdrAddress(8 downto 0) := (others => '0');
--                
--                elsif SdrRoutineSeq = 9 + page0 then
--                    SdrCmd <= SdrCmd_ac;
--                    SdrBa0_s <= SdrAddress(22); SdrBa1_s <= '1'; 
--                    SdrAdr_s <= SdrAddress(21 downto 9);
--                    colLoadNr <= to_unsigned(page0, colLoadNr'length);
--                elsif SdrRoutineSeq = 11 + page0 then
--                    SdrCmd <= SdrCmd_rd;
--                    SdrAdr_s(12 downto 9) <= "0010";
--                    SdrAdr_s(8 downto 0) <= SdrAddress(8 downto 0);
--                elsif SdrRoutineSeq >= 16 + page0 and SdrRoutineSeq < 16 + page0 + page1 then
--                    pixelOut <= pMemDat;
--                    wren_sdr <= '1';
--                    colLoadNr <= colLoadNr + 1;
--                elsif SdrRoutineSeq = 16 + page0 + page1 then
--                    SdrCmd <= SdrCmd_bs;
--                    rowLoadAck <= '1';
--                elsif SdrRoutineSeq = 17 + page0 + page1 then
--                    SdrRoutine := SdrRoutine_Idle;
--                end if;
--                SdrRoutineSeq := SdrRoutineSeq + 1;
--
--        end case;
--    end if;
--end process;
--end rtl;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sdram is
    generic(
        page0 : integer := 320;
        page1 : integer := 320
    );
    port(
        clk             : in std_logic; 
        
        -- Interfaccia Video (Verso RAM2 e VGA)
        pixelOut        : out unsigned(15 downto 0);
        rowLoadNr       : in unsigned(9 downto 0); 
        colLoadNr       : buffer unsigned(9 downto 0); 
        rowLoadReq      : in std_logic;
        rowLoadAck      : out std_logic := '0';
        wren_sdr        : out std_logic;

        -- Interfaccia AVR Direct
        addrDirect      : in unsigned(23 downto 0); 
        pixelDirectIn   : in unsigned(15 downto 0);
        directWriteReq  : in std_logic;
        directAck       : out std_logic := '0';
        
        -- Pin Fisici
        pMemClk : out std_logic; pMemCke : out std_logic; pMemCs_n : out std_logic;
        pMemRas_n : out std_logic; pMemCas_n : out std_logic; pMemWe_n : out std_logic;
        pMemUdq : out std_logic; pMemLdq : out std_logic;
        pMemBa1 : out std_logic; pMemBa0 : out std_logic;
        pMemAdr : out unsigned(12 downto 0);
        pMemDat : inout unsigned(15 downto 0)
    );
end sdram;

architecture rtl of sdram is
    signal SdrCmd : unsigned(3 downto 0);
    signal SdrBa0_s, SdrBa1_s : std_logic;
    signal SdrAdr_s : unsigned(12 downto 0);
    signal SdrDat_s : unsigned(15 downto 0);

    constant SdrCmd_pr : unsigned(3 downto 0) := "0010"; -- PRE
    constant SdrCmd_re : unsigned(3 downto 0) := "0001"; -- REFRESH
    constant SdrCmd_ms : unsigned(3 downto 0) := "0000"; -- MODE
    constant SdrCmd_xx : unsigned(3 downto 0) := "0111"; -- NOP
    constant SdrCmd_ac : unsigned(3 downto 0) := "0011"; -- ACT
    constant SdrCmd_rd : unsigned(3 downto 0) := "0101"; -- READ
    constant SdrCmd_wr : unsigned(3 downto 0) := "0100"; -- WRITE
    constant SdrCmd_bs : unsigned(3 downto 0) := "0110"; -- BURST STOP

    type typSdrRoutine is (SdrRoutine_Init, SdrRoutine_Idle, SdrRoutine_LoadRow, SdrRoutine_DirectWrite);
    
    signal curRow : unsigned(9 downto 0);
    signal sdr_write_active : std_logic := '0';

begin
    -- Mapping Fisico
    pMemClk <= clk; 
    pMemCke <= '1';
    pMemCs_n <= SdrCmd(3); pMemRas_n <= SdrCmd(2); pMemCas_n <= SdrCmd(1); pMemWe_n <= SdrCmd(0);
    pMemBa0 <= SdrBa0_s; pMemBa1 <= SdrBa1_s; pMemAdr <= SdrAdr_s; 
    pMemUdq <= '0'; pMemLdq <= '0'; 
     
    pMemDat <= SdrDat_s when sdr_write_active = '1' else (others => 'Z');

process(clk)
    variable SdrRoutine : typSdrRoutine := SdrRoutine_Init;
    variable SdrRoutineSeq : integer range 0 to 2048 := 0;
    variable SdrAddress : unsigned(23 downto 0);
begin
    if rising_edge(clk) then
        -- Default State
        SdrCmd <= SdrCmd_xx; 
        rowLoadAck <= '0'; 
        directAck <= '0'; 
        wren_sdr <= '0';
        sdr_write_active <= '0'; 

        case SdrRoutine is
            
            when SdrRoutine_Init =>
                if SdrRoutineSeq = 0 then 
                    SdrCmd <= SdrCmd_pr; SdrAdr_s <= (others => '1'); SdrBa0_s <= '0'; SdrBa1_s <= '0';
                elsif SdrRoutineSeq = 4 or SdrRoutineSeq = 12 then 
                    SdrCmd <= SdrCmd_re;
                elsif SdrRoutineSeq = 20 then 
                     SdrCmd <= SdrCmd_ms; 
                     SdrAdr_s <= "000" & '1' & "00" & "011" & "0" & "111"; -- CL3, Single Write, Full Page Read
                elsif SdrRoutineSeq = 23 then 
                    SdrRoutine := SdrRoutine_Idle; 
                end if;
                SdrRoutineSeq := SdrRoutineSeq + 1;

            when SdrRoutine_Idle =>
                if SdrRoutineSeq < 10 then -- Aumentato ritardo di guardia tra comandi
                    SdrRoutineSeq := SdrRoutineSeq + 1;
                else
                    if (rowLoadReq = '1') then
                        SdrRoutineSeq := 0;
                        SdrAddress(23 downto 19) := "00000";
                        SdrAddress(18 downto 9) := rowLoadNr;
                        curRow <= rowLoadNr;
                        SdrAddress(8 downto 0) := (others => '0');
                        SdrRoutine := SdrRoutine_LoadRow;
                    elsif (directWriteReq = '1') then
                        SdrRoutineSeq := 0;
                        SdrAddress := addrDirect;
                        SdrRoutine := SdrRoutine_DirectWrite;
                    end if;
                end if;

            when SdrRoutine_DirectWrite =>
                case SdrRoutineSeq is
                    when 0 => 
                        SdrCmd <= SdrCmd_ac; 
                        SdrBa0_s <= SdrAddress(22); SdrBa1_s <= SdrAddress(23); 
                        SdrAdr_s <= SdrAddress(21 downto 9);
                    when 2 => 
                        SdrCmd <= SdrCmd_wr; 
                        SdrAdr_s(10) <= '1'; -- Auto-Precharge
                        SdrAdr_s(8 downto 0) <= SdrAddress(8 downto 0);
                        SdrDat_s <= pixelDirectIn;
                        sdr_write_active <= '1';
                    when 3 => 
                        SdrDat_s <= pixelDirectIn;
                        sdr_write_active <= '1';
                        directAck <= '1'; -- Alziamo l'ACK subito per non bloccare l'AVR
                    when 4 => 
                        sdr_write_active <= '0';
                        SdrRoutine := SdrRoutine_Idle;
                        SdrRoutineSeq := 0;
                    when others => null;
                end case;
                SdrRoutineSeq := SdrRoutineSeq + 1;

            when SdrRoutine_LoadRow =>
                if SdrRoutineSeq = 0 then
                    SdrCmd <= SdrCmd_ac;
                    SdrBa0_s <= SdrAddress(22); SdrBa1_s <= '0';
                    SdrAdr_s <= SdrAddress(21 downto 9);
                    colLoadNr <= (others => '0');
                elsif SdrRoutineSeq = 2 then
                    SdrCmd <= SdrCmd_rd;
                    SdrAdr_s(12 downto 9) <= "0010";
                    SdrAdr_s(8 downto 0) <= SdrAddress(8 downto 0);
                elsif SdrRoutineSeq >= 7 and SdrRoutineSeq < 7 + page0 then
                    pixelOut <= pMemDat;
                    wren_sdr <= '1';
                    colLoadNr <= colLoadNr + 1;
                elsif SdrRoutineSeq = 7 + page0 then
                    SdrCmd <= SdrCmd_bs;
                    wren_sdr <= '0'; 
                    SdrAddress(23 downto 19) := "00000";
                    SdrAddress(18 downto 9) := curRow;
                    SdrAddress(8 downto 0) := (others => '0');
                
                elsif SdrRoutineSeq = 9 + page0 then
                    SdrCmd <= SdrCmd_ac;
                    SdrBa0_s <= SdrAddress(22); SdrBa1_s <= '1'; 
                    SdrAdr_s <= SdrAddress(21 downto 9);
                    colLoadNr <= to_unsigned(page0, colLoadNr'length);
                elsif SdrRoutineSeq = 11 + page0 then
                    SdrCmd <= SdrCmd_rd;
                    SdrAdr_s(12 downto 9) <= "0010";
                    SdrAdr_s(8 downto 0) <= SdrAddress(8 downto 0);
                elsif SdrRoutineSeq >= 16 + page0 and SdrRoutineSeq < 16 + page0 + page1 then
                    pixelOut <= pMemDat;
                    wren_sdr <= '1';
                    colLoadNr <= colLoadNr + 1;
                elsif SdrRoutineSeq = 16 + page0 + page1 then
                    SdrCmd <= SdrCmd_bs;
                    rowLoadAck <= '1';
                elsif SdrRoutineSeq = 17 + page0 + page1 then
                    SdrRoutine := SdrRoutine_Idle;
                end if;
                SdrRoutineSeq := SdrRoutineSeq + 1;

        end case;
    end if;
end process;
end rtl;