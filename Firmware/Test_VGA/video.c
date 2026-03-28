
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>
#include "video.h"
#include "Font16.h"


uint16_t _width = 640;
uint16_t _height = 480;
uint8_t  _rotation = 0;
uint16_t textcolor, textbgcolor, fontsloaded, addr_row, addr_col;
int16_t  cursor_x, cursor_y, win_xe, win_ye, padX;
uint8_t  textfont, textsize, textdatum, rotation;

/* --- ROUTINE BASE --- */


/**
 * Configura la modalità di visualizzazione
 */
void video_config(uint8_t video_on, uint8_t scanline_off) {
    uint8_t ctrl = 0;

    // Bit 1: 1 = Video Attivo (RAM Mode), 0 = Test Mode (o Spento)
    if (video_on)     ctrl |= VIDEO_ENABLE_BIT;   // (1 << 1)
    
    // Bit 2: 1 = Scanline OFF, 0 = Scanline ON
    if (scanline_off) ctrl |= VIDEO_SCANLINE_OFF; // (1 << 2)

    // Scriviamo il registro di controllo. 
    // Il Bit 0 (Store) rimane a '0' di default qui.
    VGA_REG_CTRL = ctrl;
}

/***************************************************************************************
** Function name:           setTextFont
** Description:             Set the font for the print stream
***************************************************************************************/
void vga_setTextFont(uint8_t f)
{
  textfont = (f > 0) ? f : 1; // Don't allow font 0
}

/***************************************************************************************
** Function name:           setTextSize
** Description:             Set the text size multiplier
***************************************************************************************/
void vga_setTextSize(uint8_t s)
{
  if (s>7) s = 7; // Limit the maximum size multiplier so byte variables can be used for rendering
  textsize = (s > 0) ? s : 1; // Don't allow font size 0
}

/***************************************************************************************
** Function name:           setTextColor
** Description:             Set the font foreground and background colour
***************************************************************************************/
void vga_setTextColor(uint16_t c, uint16_t b)
{
  textcolor   = c;
  textbgcolor = b;
}


void vga_pixel_fast(uint16_t x, uint16_t y, uint16_t color) {
    // Aspetta che la SDRAM sia libera prima di iniziare (se c'è un'operazione pendente)
    uint16_t timeout = 1000;
    while((VGA_REG_STAT & 0x01) && --timeout); 

    VIDEO_REG_X_L = (uint8_t)(x & 0xFF);
    VIDEO_REG_X_H = (uint8_t)((x >> 8) & 0x03);
    VIDEO_REG_Y_L = (uint8_t)(y & 0xFF);
    VIDEO_REG_Y_H = (uint8_t)((y >> 8) & 0x03);
    
    VIDEO_REG_DATA_L = (uint8_t)(color & 0xFF);
    VIDEO_REG_DATA_H = (uint8_t)(color >> 8); 
    

}

// Test: Riempiamo una zona dello schermo
void test_fill() {
    for(uint16_t i=0; i<200; i++) {
        for(uint16_t j=0; j<200; j++) {
            vga_pixel_fast(i + 300, j + 100, YELLOW); // Un bel quadrato rosso
        }
    }
}

void vga_clear_screen(uint16_t color) {
    uint16_t x, y;
    uint16_t timeout = 1000;
    // Separiamo i componenti del colore fuori dal loop per risparmiare cicli CPU
    uint8_t color_l = (uint8_t)(color & 0xFF);
    uint8_t color_h = (uint8_t)(color >> 8);

    for (y = 0; y < 480; y++) {
        // Carichiamo Y (cambia solo una volta per ogni riga)
        VIDEO_REG_Y_L = (uint8_t)(y & 0xFF);
        VIDEO_REG_Y_H = (uint8_t)((y >> 8) & 0x03);

        for (x = 0; x < 640; x++) {
            // Carichiamo X
            VIDEO_REG_X_L = (uint8_t)(x & 0xFF);
            VIDEO_REG_X_H = (uint8_t)((x >> 8) & 0x03);

            // Scriviamo il colore (L poi H per attivare la scrittura hardware)
            VIDEO_REG_DATA_L = color_l;
            VIDEO_REG_DATA_H = color_h; 
            
            while((VGA_REG_STAT & 0x01) && --timeout); 
        }
    }
}

void vga_fillRect(uint16_t x, uint16_t y, uint16_t w, uint16_t h, uint16_t color) {
    uint16_t x_end = x + w;
    uint16_t y_end = y + h;
    uint16_t timeout = 1000;
    // Suddividiamo il colore per evitare lo shift dentro il loop
    uint8_t color_lo = (uint8_t)(color & 0xFF);
    uint8_t color_hi = (uint8_t)(color >> 8);

    for (uint16_t i = y; i < y_end; i++) {
        // Impostiamo la coordinata Y una sola volta per riga per risparmiare cicli
        while(VGA_REG_STAT & 0x01); // Attesa ACK se necessario
        VIDEO_REG_Y_L = (uint8_t)(i & 0xFF);
        VIDEO_REG_Y_H = (uint8_t)((i >> 8) & 0x03);

        for (uint16_t j = x; j < x_end; j++) {
            // Attesa che la SDRAM finisca l'operazione precedente
            // Questo garantisce che non perdiamo pixel (niente diagonali!)
            while(VGA_REG_STAT & 0x01); 

            // Impostiamo X
            VIDEO_REG_X_L = (uint8_t)(j & 0xFF);
            VIDEO_REG_X_H = (uint8_t)((j >> 8) & 0x03);
            
            // Inviamo il colore (il trigger di scrittura è su DATA_H)
            VIDEO_REG_DATA_L = color_lo;
            VIDEO_REG_DATA_H = color_hi; 
            while((VGA_REG_STAT & 0x01) && --timeout);
        }
    }
}

/***************************************************************************************
** Function name:           vga_drawChar
** Description:            Disegna un carattere usando i font in Flash (AVR)
***************************************************************************************/
int vga_drawChar(unsigned int uniCode, int x, int y, int font) {
    // Gestione Font 1 (GLCD) - Se l'hai implementata
    if (font == 1) {
        #ifdef LOAD_GLCD
            // tft_drawCharGL(x, y, uniCode, textcolor, textbgcolor, textsize);
            return 6 * textsize;
        #else
            return 0;
        #endif
    }

    int width = 0;
    int height = 0;
    uint32_t flash_address = 0; 
    
    if (uniCode < 32) return 0;
    uniCode -= 32;

#ifdef LOAD_FONT2
    if (font == 2) {
        // Legge i dati del font dalla Flash dell'AVR
        flash_address = pgm_read_word(&chrtbl_f16[uniCode]);
        width = pgm_read_byte(widtbl_f16 + uniCode);
        height = chr_hgt_f16;
    }
#endif

    int w_bytes = (width + 7) / 8; // Quanti byte occupa una riga di questo carattere
    uint8_t line = 0;

    // --- CASO 1: Font Scalato o Trasparente (Lento) ---
    if (textcolor == textbgcolor || textsize != 1) {
        for (int i = 0; i < height; i++) {
            // Sfondo riga (se non trasparente)
            if (textcolor != textbgcolor) {
                vga_fillRect(x, y + (i * textsize), width * textsize, textsize, textbgcolor);
            }

            for (int k = 0; k < w_bytes; k++) {
                line = pgm_read_byte(flash_address + w_bytes * i + k);
                if (line) {
                    int pX = x + (k * 8 * textsize);
                    for (int bit = 0; bit < 8; bit++) {
                        if (line & (0x80 >> bit)) {
                            if (textsize == 1) {
                                vga_pixel_fast(pX + bit, y + i, textcolor);
                            } else {
                                vga_fillRect(pX + bit * textsize, y + i * textsize, textsize, textsize, textcolor);
                            }
                        }
                    }
                }
            }
        }
    } 
    // --- CASO 2: Font Standard (Veloce) ---
    else {
        // Scrittura pixel per pixel sincronizzata con la SDRAM
        for (int i = 0; i < height; i++) {
            int current_y = y + i;
            
            // Impostiamo Y una volta per riga per risparmiare tempo
            while(VGA_REG_STAT & 0x01);
            VIDEO_REG_Y_L = (uint8_t)(current_y & 0xFF);
            VIDEO_REG_Y_H = (uint8_t)((current_y >> 8) & 0x03);

            for (int k = 0; k < w_bytes; k++) {
                line = pgm_read_byte(flash_address + w_bytes * i + k);
                int base_x = x + (k * 8);

                for (int bit = 0; bit < 8; bit++) {
                    // Non disegnare oltre la larghezza reale del carattere
                    if ((k * 8) + bit >= width) break;

                    int current_x = base_x + bit;
                    uint16_t color = (line & (0x80 >> bit)) ? textcolor : textbgcolor;

                    // Aspetta l'hardware e scrivi
                    while(VGA_REG_STAT & 0x01);
                    VIDEO_REG_X_L = (uint8_t)(current_x & 0xFF);
                    VIDEO_REG_X_H = (uint8_t)((current_x >> 8) & 0x03);
                    
                    VIDEO_REG_DATA_L = (uint8_t)(color & 0xFF);
                    VIDEO_REG_DATA_H = (uint8_t)(color >> 8);
                }
            }
        }
    }

    return width * textsize;
}

/***************************************************************************************
** Function name:           vga_printAt
** Description:            Stampa una stringa sulla SDRAM usando vga_drawChar
***************************************************************************************/
void vga_printAt(const char *str, int16_t x, int16_t y, uint16_t color, uint16_t bg, uint8_t font) {
    int16_t curX = x;
    
    // Impostiamo le variabili globali utilizzate da vga_drawChar
    textcolor = color;
    textbgcolor = bg;
    textsize = 1; // Forza dimensione standard per la UI del DSO

    // Se la stringa è in RAM
    while (*str) {
        // Chiamiamo la funzione che abbiamo convertito prima
        // curX viene incrementato della larghezza del carattere appena disegnato
        int charWidth = vga_drawChar((unsigned int)*str, curX, y, font);
        
        // Se vga_drawChar restituisce 0 (es. carattere non valido), evitiamo loop infiniti
        if (charWidth == 0 && *str != ' ') {
            str++;
            continue;
        }

        curX += charWidth;
        str++;
        
        // Protezione margine destro (640 pixel nel tuo caso)
        // Usiamo 640 invece di _width se non hai la variabile definita
        if (curX > 635) break; 
    }
}

void vga_drawFastHLine(int16_t x, int16_t y, int16_t w, uint16_t color) {
    if (w < 0) { x += w; w = -w; }
    
    // Imposta Y una sola volta per tutta la linea
    while(VGA_REG_STAT & 0x01);
    VIDEO_REG_Y_L = (uint8_t)(y & 0xFF);
    VIDEO_REG_Y_H = (uint8_t)((y >> 8) & 0x03);

    uint8_t color_lo = (uint8_t)(color & 0xFF);
    uint8_t color_hi = (uint8_t)(color >> 8);

    for (int16_t i = 0; i < w; i++) {
        int16_t curX = x + i;
        if (curX < 0 || curX >= 640) continue; // Clipping base

        while(VGA_REG_STAT & 0x01);
        VIDEO_REG_X_L = (uint8_t)(curX & 0xFF);
        VIDEO_REG_X_H = (uint8_t)((curX >> 8) & 0x03);
        
        VIDEO_REG_DATA_L = color_lo;
        VIDEO_REG_DATA_H = color_hi;
    }
}

void vga_drawFastVLine(int16_t x, int16_t y, int16_t h, uint16_t color) {
    if (h <= 0) return;
    if (x < 0 || x >= 640) return; // Clipping X

    // Imposta X una sola volta per tutta la linea verticale
    while(VGA_REG_STAT & 0x01);
    VIDEO_REG_X_L = (uint8_t)(x & 0xFF);
    VIDEO_REG_X_H = (uint8_t)((x >> 8) & 0x03);

    uint8_t color_lo = (uint8_t)(color & 0xFF);
    uint8_t color_hi = (uint8_t)(color >> 8);

    for (int16_t i = 0; i < h; i++) {
        int16_t curY = y + i;
        if (curY < 0 || curY >= 480) continue; // Clipping Y

        // Attendiamo che la SDRAM sia pronta
        while(VGA_REG_STAT & 0x01);
        
        // Aggiorniamo solo la Y
        VIDEO_REG_Y_L = (uint8_t)(curY & 0xFF);
        VIDEO_REG_Y_H = (uint8_t)((curY >> 8) & 0x03);
        
        // Scrittura pixel (trigger su DATA_H)
        VIDEO_REG_DATA_L = color_lo;
        VIDEO_REG_DATA_H = color_hi;
    }
}

/***************************************************************************************
** Function name:           vga_drawRect
** Description:            Disegna il contorno di un rettangolo
***************************************************************************************/
void vga_drawRect(int16_t x, int16_t y, int16_t w, int16_t h, uint16_t color) {
    if (w <= 0 || h <= 0) return;

    // Disegna i quattro lati sfruttando le ottimizzazioni di riga/colonna
    vga_drawFastHLine(x, y, w, color);             // Lato superiore
    vga_drawFastHLine(x, y + h - 1, w, color);     // Lato inferiore
    vga_drawFastVLine(x, y, h, color);             // Lato sinistro
    vga_drawFastVLine(x + w - 1, y, h, color);     // Lato destro
}

/***************************************************************************************
** Function name:           vga_fillCircle
** Description:            Disegna un cerchio pieno a (x0, y0)
***************************************************************************************/
void vga_fillCircle(uint16_t x0, uint16_t y0, uint16_t r, uint16_t color) {
    // Disegna la linea centrale (diametro orizzontale)
    vga_drawFastHLine(x0 - r, y0, 2 * r + 1, color);

    int16_t f = 1 - r;
    int16_t ddF_x = 1;
    int16_t ddF_y = -2 * r;
    int16_t x = 0;
    int16_t y = r;

    while (x < y) {
        if (f >= 0) {
            y--;
            ddF_y += 2;
            f += ddF_y;
        }
        x++;
        ddF_x += 2;
        f += ddF_x;

        // Disegna le linee orizzontali tra i punti speculari per riempire il cerchio
        // Sfruttiamo la simmetria degli ottanti
        vga_drawFastHLine(x0 - x, y0 + y, 2 * x + 1, color);
        vga_drawFastHLine(x0 - x, y0 - y, 2 * x + 1, color);
        vga_drawFastHLine(x0 - y, y0 + x, 2 * y + 1, color);
        vga_drawFastHLine(x0 - y, y0 - x, 2 * y + 1, color);
    }
}

/***************************************************************************************
** Function name:           vga_drawLine
** Description:            Disegna una linea tra (x1,y1) e (x2,y2) - Algoritmo Bresenham
***************************************************************************************/
void vga_drawLine(int16_t x1, int16_t y1, int16_t x2, int16_t y2, uint16_t color) {
    // 1. OTTIMIZZAZIONE: Linee perfettamente orizzontali o verticali
    if (x1 == x2) {
        vga_drawFastVLine(x1, (y1 < y2 ? y1 : y2), abs(y2 - y1) + 1, color);
        return;
    }
    if (y1 == y2) {
        vga_drawFastHLine((x1 < x2 ? x1 : x2), y1, abs(x2 - x1) + 1, color);
        return;
    }

    // 2. PREPARAZIONE BRESENHAM
    bool steep = abs(y2 - y1) > abs(x2 - x1);
    if (steep) {
        // Swap x1, y1
        int16_t t = x1; x1 = y1; y1 = t;
        // Swap x2, y2
        t = x2; x2 = y2; y2 = t;
    }

    if (x1 > x2) {
        // Swap inizio con fine
        int16_t t = x1; x1 = x2; x2 = t;
        t = y1; y1 = y2; y2 = t;
    }

    int16_t dx = x2 - x1;
    int16_t dy = abs(y2 - y1);
    int16_t err = dx / 2;
    int16_t ystep = (y1 < y2) ? 1 : -1;

    // 3. LOOP DI DISEGNO
    // Usiamo vga_pixel_fast che ha già i controlli di ACK per la SDRAM
    for (; x1 <= x2; x1++) {
        if (steep) {
            vga_pixel_fast(y1, x1, color);
        } else {
            vga_pixel_fast(x1, y1, color);
        }

        err -= dy;
        if (err < 0) {
            y1 += ystep;
            err += dx;
        }
    }
}

/***************************************************************************************
** Function name:           tft_printCenteredX
** Description:             Stampa una stringa centrata orizzontalmente in un'area
** delimitata da xStart e xEnd alla coordinata Y specificata.
***************************************************************************************/
void vga_printCenteredX(const char *str, int16_t xStart, int16_t xEnd, int16_t y, uint16_t color, uint16_t bg, uint8_t font) {
    uint16_t textWidth = 0;
    uint16_t len = strlen(str);
    
    if (len == 0) return; // Evitiamo calcoli inutili

    if (font == 2) {
    #ifdef LOAD_FONT2
    for (uint16_t i = 0; i < len; i++) {
        uint8_t uniCode = (uint8_t)str[i];

        // PROTEZIONE: Se il carattere è inferiore allo spazio (ASCII 32), ignoralo o usa 32
        if (uniCode < 32) uniCode = 32;

        // Sottrai 32 perché la tabella widtbl_f16 solitamente inizia dallo spazio
        // Se continua a sballare, prova a controllare il file del font per vedere l'offset
        textWidth += pgm_read_byte(widtbl_f16 + (uniCode - 32));
    }
    textWidth--; 
    #endif
} else {
        // Per il Font 1, di solito è 6 pixel totali (5 carattere + 1 spazio)
        textWidth = (len * 6 * font) - 1; 
    }

    int16_t areaWidth = xEnd - xStart;
    int16_t centeredX = xStart + (areaWidth - textWidth) / 2;

    // Se il calcolo porta il testo fuori a sinistra, forziamo l'inizio all'area
   // if (centeredX < xStart) centeredX = xStart;

    tft_printAt(str, centeredX, y, color, bg, font);
}