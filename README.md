Tiny_DSO_VGA: 65MSPS Digital Storage Oscilloscope (VGA Edition)
Un oscilloscopio digitale ad alte prestazioni basato su architettura eterogenea FPGA (Intel Cyclone IV) e Soft-Processor AVR @ 60MHz. 
Questa versione sposta i limiti del progetto originale eliminando i colli di bottiglia dei display SPI, implementando un controller VGA 640x480 con memoria video su SDRAM.

<p align="center">
<img src="assets/vga_screenshot.JPG" alt="Tiny DSO VGA Preview" width="600">
</p>

🚀 Caratteristiche Principali
Sampling Rate: 65 MSPS (Real-time) tramite ADC parallelo 12-bit.

Risoluzione Video: 640x480 @ 60Hz (Standard VGA).

Core CPU: AVR V8 Soft-Core sintetizzato @ 60 MHz (FPGA-Optimized).

Video Engine: Controller VGA hardware-native con supporto RGB333 (512 colori).

Memory Management: Gestione dinamica della SDRAM a 114MHz per buffering video e cattura campioni.

Latenza Trigger: Unità hardware dedicata con risposta ultra-rapida (15.4ns).

Firmware Size: Solo 27 KB di codice C puro (efficienza estrema).

🛠️ Architettura del Sistema
Il sistema sfrutta la potenza della logica programmabile per gestire il flusso dati massivo richiesto dalla VGA senza gravare sulla CPU:

1. Hardware (VHDL/Verilog)
SDRAM Controller: Gestisce l'arbitraggio tra il "Snooping" (Interception) dell'AVR e il refresh costante della VGA.

VGA Video Out: Generazione dei segnali di timing (HSync/VSync) e gestione dei 9-bit di colore (3R-3G-3B).

ADC Interfacing: Cattura sincrona a 12-bit (AD9226) con buffering in Block RAM.

Clock Management: PLL dedicate per generare i 114.5MHz (SDRAM) e 25.175MHz (VGA Pixel Clock).

2. Firmware (C)
Snooping Protocol: Protocollo di accesso alla memoria video che permette all'AVR di modificare i pixel direttamente nel ciclo di scansione hardware.

Graphics Engine: Libreria ottimizzata per il disegno di griglie, testi e forme d'onda su risoluzione 640x480.

UI Scalata: Interfaccia riprogettata per sfruttare l'area di visualizzazione estesa, separando la zona traccia dai parametri di misura.

📦 Requisiti di Sviluppo
FPGA Board: Intel/Altera Cyclone IV (ottimizzato per DE0-Nano).

ADC Hardware: Modulo AD9226 (12-bit, 65MSPS).

Monitor: Qualsiasi display con ingresso VGA standard.

Toolchain: AVR-GCC 15.1 o superiore.

Sintesi: Quartus Prime Lite Edition.

Developed by Joe (MJE) 2026. Special thanks to M. Montanari (Perry) for the experimental PCB layout and wiring.