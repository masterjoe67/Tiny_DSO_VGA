

#ifndef VIDEO_H
#define VIDEO_H

#include <avr/io.h>


// FEEDBACK SU INDIRIZZO MMIO 0x08
// Usiamo l'accesso diretto all'indirizzo I/O 0x08
#define VIDEO_STATUS_REG  _SFR_IO8(0x08) 


#define VGA_REG_CTRL    _SFR_IO8(0x18) // Scrittura/Lettura Controllo
#define VGA_REG_STAT    _SFR_IO8(0x08) // Lettura Stato (Busy/Ack)

// Bitmask per il registro di controllo
#define VIDEO_STORE_BIT    (1 << 0) // Avvia il trasferimento SDRAM
#define VIDEO_ENABLE_BIT   (1 << 1) // 1 = Acceso, 0 = Spento
#define VIDEO_SCANLINE_OFF (1 << 2) // 1 = Scanline disattivate

#define VIDEO_BRAM_BASE ((volatile uint16_t*)0x4100)

/* --- DEFINIZIONI INDIRIZZI REGISTRI (BRAM/CONFIG) --- */
#define VIDEO_REG_X_L      (*(volatile uint8_t *)(0x4050))
#define VIDEO_REG_X_H      (*(volatile uint8_t *)(0x4051))
#define VIDEO_REG_Y_L      (*(volatile uint8_t *)(0x4052))
#define VIDEO_REG_Y_H      (*(volatile uint8_t *)(0x4053))
#define VIDEO_REG_DATA_L   (*(volatile uint8_t *)(0x4054))
#define VIDEO_REG_DATA_H   (*(volatile uint8_t *)(0x4055))

// Colori Base
#define BLACK       0x0000
#define NAVY        0x000F
#define DARKGREEN   0x03E0
#define DARKCYAN    0x03EF
#define MAROON      0x7800
#define PURPLE      0x780F
#define OLIVE       0x7BE0
#define LIGHTGREY   0xC618

// Colori Brillanti (Ideali per tracce DSO)
#define BLUE        0x001F
#define GREEN       0x07E0
#define CYAN        0x07FF
#define RED         0xF800
#define MAGENTA     0xF81F
#define YELLOW      0xFFE0
#define WHITE       0xFFFF
#define ORANGE      0xFD20
#define GREENYELLOW 0xAFE5
#define PINK        0xF81F

// Sfumature di Grigio
#define DARKGREY    0x3186  // Grigio molto scuro (per sfondi barre)
#define GREY        0x8410  // Grigio medio (per la griglia)
#define LIGHTGREY   0xC618  // Grigio chiaro (per testi disattivi)

#define LOAD_FONT2
#define LOAD_GLCD



/* --- ROUTINE BASE --- */


/**
 * Configura la modalità di visualizzazione
 */
void video_config(uint8_t video_on, uint8_t scanline_off);

void vga_pixel_fast(uint16_t x, uint16_t y, uint16_t color);

void vga_drawFastHLine(int16_t x, int16_t y, int16_t w, uint16_t color);

void vga_drawFastVLine(int16_t x, int16_t y, int16_t h, uint16_t color);

void vga_fillCircle(uint16_t x0, uint16_t y0, uint16_t r, uint16_t color);

void vga_drawRect(int16_t x, int16_t y, int16_t w, int16_t h, uint16_t color);

void vga_drawLine(int16_t x1, int16_t y1, int16_t x2, int16_t y2, uint16_t color);

void vga_setTextFont(uint8_t f);

void vga_setTextSize(uint8_t s);

void vga_setTextColor(uint16_t c, uint16_t b);

void vga_clear_screen(uint16_t color);

void vga_fillRect(uint16_t x, uint16_t y, uint16_t w, uint16_t h, uint16_t color);

int vga_drawChar(unsigned int uniCode, int x, int y, int font);

void vga_printAt(const char *str, int16_t x, int16_t y, uint16_t color, uint16_t bg, uint8_t font);

void vga_printCenteredX(const char *str, int16_t xStart, int16_t xEnd, int16_t y, uint16_t color, uint16_t bg, uint8_t font) ;

// Test: Riempiamo una zona dello schermo
void test_fill();



#endif // VIDEO_H
