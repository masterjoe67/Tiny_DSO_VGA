

#ifndef VIDEO_H
#define VIDEO_H

#include <avr/io.h>
#include <stddef.h>

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
#define VIDEO_REG_X_L      (*(volatile uint8_t *)(0x5050))
#define VIDEO_REG_X_H      (*(volatile uint8_t *)(0x5051))
#define VIDEO_REG_Y_L      (*(volatile uint8_t *)(0x5052))
#define VIDEO_REG_Y_H      (*(volatile uint8_t *)(0x5053))
#define VIDEO_REG_DATA_L   (*(volatile uint8_t *)(0x5054))
#define VIDEO_REG_DATA_H   (*(volatile uint8_t *)(0x5055))

// Colori Base
// Formato binario: 0000000 RRRG GGBB B
// Colori Base (Intensità massima)
#define BLACK   0x0000
#define RED     0x01C0  // 111 000 000
#define GREEN   0x0038  // 000 111 000
#define BLUE    0x0007  // 000 000 111

// Colori Composti (DSO Style)
#define YELLOW  0x01F8  // Rosso + Verde (111 111 000)
#define CYAN    0x003F  // Verde + Blu   (000 111 111)
#define MAGENTA 0x01C7  // Rosso + Blu   (111 000 111)
#define WHITE   0x01FF  // Tutto acceso  (111 111 111)

// Colori Tenui (per la griglia o menu)
#define GREY    0x0092  // Grigio medio  (010 010 010)
#define DARKGREY 0x0049 // Grigio scuro (001 001 001)

#define LOAD_FONT2
#define LOAD_GLCD

typedef struct {
    int16_t x;
    int16_t y;
} Point_t;

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

void vga_FillTriangle(Point_t p0, Point_t p1, Point_t p2, uint16_t color);

void vga_setTextFont(uint8_t f);

void vga_setTextSize(uint8_t s);

void vga_setTextColor(uint16_t c, uint16_t b);

void vga_set_cursor(int x, int y);

void vga_clear_screen(uint16_t color);

void vga_fillRect(uint16_t x, uint16_t y, uint16_t w, uint16_t h, uint16_t color);

int vga_drawChar(unsigned int uniCode, int x, int y, int font);

void vga_printAt(const char *str, int16_t x, int16_t y, uint16_t color, uint16_t bg, uint8_t font);

void vga_printCenteredX(const char *str, int16_t xStart, int16_t xEnd, int16_t y, uint16_t color, uint16_t bg, uint8_t font) ;

void vga_Print_int16(int16_t value);

void vga_print_float(float value, uint8_t decimals);

void vga_Print(const char *str);

size_t vga_write(uint8_t uniCode);

void vga_print_int(int32_t num);

void vga_drawLine_Clipped(uint16_t x1, uint16_t y1, uint16_t x2, uint16_t y2, uint16_t color, uint16_t y_min, uint16_t y_max);

// Test: Riempiamo una zona dello schermo
void test_fill();



#endif // VIDEO_H
