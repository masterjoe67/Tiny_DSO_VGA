
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <stddef.h>
#include <avr/pgmspace.h>
#include "video.h"
#include "Font16.h"


uint16_t _width = 640;
uint16_t _height = 480;
uint8_t  _rotation = 0;
uint16_t textcolor, textbgcolor, fontsloaded, addr_row, addr_col;
int16_t  cursor_x, cursor_y, win_xe, win_ye, padX;
uint8_t  textfont, textsize, textdatum, rotation;
bool  textwrap = true;

/* --- ROUTINE BASE --- */

// Funzione di utilità per lo swap (se non l'hai già definita altrove)
void swap_int16(int16_t *a, int16_t *b) {
    int16_t temp = *a;
    *a = *b;
    *b = temp;
}
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

void vga_set_cursor(int x, int y) {
    cursor_x = x;
    cursor_y = y;
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

    vga_printAt(str, centeredX, y, color, bg, font);
}

/***************************************************************************************
** Function name:           vga_FillTriangle
** Description:            Disegna un triangolo pieno usando la struttura Point_t
***************************************************************************************/
void vga_FillTriangle(Point_t p0, Point_t p1, Point_t p2, uint16_t color) {
    // 1. Ordinamento dei vertici per coordinata Y: p0 è il più alto, p2 il più basso
    if (p0.y > p1.y) { swap_int16(&p0.y, &p1.y); swap_int16(&p0.x, &p1.x); }
    if (p1.y > p2.y) { swap_int16(&p1.y, &p2.y); swap_int16(&p1.x, &p2.x); }
    if (p0.y > p1.y) { swap_int16(&p0.y, &p1.y); swap_int16(&p0.x, &p1.x); }

    int16_t total_height = p2.y - p0.y;
    if (total_height == 0) return; // Protezione: triangolo degenere

    // 2. Loop di scansione riga per riga
    for (int16_t y = p0.y; y <= p2.y; y++) {
        // Determina se siamo nella metà superiore o inferiore
        bool second_half = (y > p1.y || p1.y == p0.y);
        int16_t segment_height = second_half ? (p2.y - p1.y) : (p1.y - p0.y);
        
        if (segment_height == 0) continue; 

        // 3. Calcolo dei coefficienti di interpolazione (float per precisione)
        float alpha = (float)(y - p0.y) / total_height;
        float beta  = (float)(y - (second_half ? p1.y : p0.y)) / segment_height;

        // 4. Calcolo delle coordinate X iniziali e finali
        int16_t ax = p0.x + (int16_t)((p2.x - p0.x) * alpha);
        int16_t bx = second_half
            ? p1.x + (int16_t)((p2.x - p1.x) * beta)
            : p0.x + (int16_t)((p1.x - p0.x) * beta);

        // 5. Riempimento: usa la nostra drawFastHLine ottimizzata
        if (ax > bx) swap_int16(&ax, &bx);
        
        // Disegniamo la riga
        vga_drawFastHLine(ax, y, (bx - ax + 1), color);
    }
}

/***************************************************************************************
** Function name:           vga_print
** Description:            Invia una stringa al display carattere per carattere
***************************************************************************************/
void vga_Print(const char *str) {
    while(*str) {
        // Chiama la funzione che gestisce il disegno e il cursore
        vga_write((uint8_t)*str++);
    }
}

/***************************************************************************************
** Function name:           vga_printInt16
** Description:            Converte un int16 in stringa e lo stampa su SDRAM
***************************************************************************************/
void vga_Print_int16(int16_t value) {
    // 1. Gestione del segno negativo
    if (value < 0) {
        vga_Print("-");
        value = -value;
    }

    // 2. Caso particolare: lo zero
    if (value == 0) {
        vga_Print("0");
        return;
    }

    // 3. Buffer per la conversione (massimo 5 cifre per un int16 + terminatore)
    char buffer[7]; 
    uint8_t i = 0;

    // Estraiamo le cifre partendo dall'ultima
    while (value > 0) {
        buffer[i++] = (value % 10) + '0';
        value /= 10;
    }

    // 4. Stampa le cifre in ordine inverso
    while (i > 0) {
        char s[2] = {buffer[--i], '\0'};
        vga_Print(s);
    }
}

void vga_print_float(float value, uint8_t decimals) {
    // 1. Gestione numeri negativi
    if (value < 0) {
        vga_Print("-");
        value = -value;
    }

    // 2. Stampa la parte intera
    uint32_t integral = (uint32_t)value;
    vga_print_int(integral); // Uso la tua funzione per gli interi

    // 3. Stampa il punto decimale
    if (decimals > 0) {
        vga_Print(".");
        
        // 4. Calcola e stampa i decimali
        float fraction = value - (float)integral;
        for (uint8_t i = 0; i < decimals; i++) {
            fraction *= 10.0f;
            uint8_t digit = (uint8_t)fraction;
            vga_print_int(digit);
            fraction -= (float)digit;
        }
    }
}

void vga_print_int(int32_t num) {
    char buffer[12]; // Abbastanza per un long con segno e terminatore
    uint8_t i = 0;

    // 1. Gestione dello zero
    if (num == 0) {
        vga_Print("0");
        return;
    }

    // 2. Gestione numeri negativi
    if (num < 0) {
        vga_Print("-");
        num = -num;
    }

    // 3. Estrazione delle cifre (partendo dall'ultima)
    while (num > 0) {
        buffer[i++] = (num % 10) + '0'; // Trasforma la cifra in carattere ASCII
        num /= 10;
    }

    // 4. Stampa le cifre in ordine corretto (dall'ultima estratta alla prima)
    while (i > 0) {
        char c[2] = {buffer[--i], '\0'}; // tft_print di solito vuole una stringa
        vga_Print(c);
    }
}

/***************************************************************************************
** Function name:           vga_write (ex tft_write)
** Description:            Gestisce il flusso dei caratteri aggiornando i cursori x e y
***************************************************************************************/
size_t vga_write(uint8_t uniCode)
{
    // 1. Gestione rapida del Carriage Return
    if (uniCode == '\r') return 1;

    unsigned int width = 0;
    unsigned int height = 0;

#ifdef LOAD_FONT2
    if (textfont == 2)
    {
        // Calcolo larghezza font 2 (ottimizzato pgm_read)
        width = pgm_read_byte(widtbl_f16 + uniCode - 32);
        height = chr_hgt_f16;
        // Font 2 is rendered in whole byte widths
        width = (width + 6) / 8;
        width = width * 8; 
    }
    #ifdef LOAD_RLE
    else
    #endif
#endif

#ifdef LOAD_RLE
    {
        // Calcolo per font RLE tramite struttura fontdata
        width = pgm_read_byte(pgm_read_word(&(fontdata[textfont].widthtbl)) + uniCode - 32);
        height = pgm_read_byte(&fontdata[textfont].height);
    }
#endif

#ifdef LOAD_GLCD
    if (textfont == 1)
    {
        width = 6;
        height = 8;
    }
#else
    if (textfont == 1) return 0;
#endif

    // Applichiamo la scalatura del testo
    height = height * textsize;

    // 2. Gestione New Line
    if (uniCode == '\n') {
        cursor_y += height;
        cursor_x  = 0;
    }
    else
    {
        // 3. Gestione Text Wrap (se attivo)
        // _width nel tuo caso è 640
        if (textwrap && (cursor_x + width * textsize >= 640))
        {
            cursor_y += height;
            cursor_x = 0;
        }

        // 4. DISEGNO FISICO E AGGIORNAMENTO CURSORE
        // Chiamiamo la nostra vga_drawChar che abbiamo adattato per la SDRAM.
        // Restituisce la larghezza reale per far avanzare il cursore correttamente.
        cursor_x += vga_drawChar(uniCode, cursor_x, cursor_y, textfont);
    }

    return 1;
}

void vga_drawLine_Clipped(uint16_t x1, uint16_t y1, uint16_t x2, uint16_t y2, uint16_t color, uint16_t y_min, uint16_t y_max) {
    // 1. Caso speciale: Linee perfettamente dritte
    if (x1 == x2) {
        // Linea verticale: dobbiamo clippare l'inizio e la fine della linea stessa
        int16_t startY = (y1 < y2 ? y1 : y2);
        int16_t endY = (y1 > y2 ? y1 : y2);
        
        if (startY < y_min) startY = y_min;
        if (endY > y_max)   endY = y_max;
        
        if (startY <= endY) {
            vga_drawFastVLine(x1, startY, (endY - startY) + 1, color);
        }
        return;
    }
    
    if (y1 == y2) {
        // Linea orizzontale: la disegnamo solo se la Y è nel range
        if (y1 >= y_min && y1 <= y_max) {
            vga_drawFastHLine((x1 < x2 ? x1 : x2), y1, abs((int16_t)x2 - (int16_t)x1) + 1, color);
        }
        return;
    }

    // 2. Logica di Bresenham standard
    int16_t x = x1;
    int16_t y = y1;
    int16_t x_fine = x2;
    int16_t y_fine = y2;

    bool steep = abs(y_fine - y) > abs(x_fine - x);
    if (steep) {
        int16_t tmp;
        tmp = x; x = y; y = tmp;
        tmp = x_fine; x_fine = y_fine; y_fine = tmp;
    }

    if (x > x_fine) {
        int16_t tmp;
        tmp = x; x = x_fine; x_fine = tmp;
        tmp = y; y = y_fine; y_fine = tmp;
    }

    int16_t dx = x_fine - x;
    int16_t dy = abs(y_fine - y);
    int16_t err = dx / 2;
    int16_t ystep = (y < y_fine) ? 1 : -1;

    // 3. Ciclo di disegno con clipping
    for (; x <= x_fine; x++) {
        // Determiniamo quali sono le coordinate reali correnti
        int16_t realX = steep ? y : x;
        int16_t realY = steep ? x : y;

        // --- CLIPPING CHECK ---
        // Disegniamo il pixel solo se la coordinata Y reale è nei limiti
        if (realY >= y_min && realY <= y_max) {
            vga_pixel_fast(realX, realY, color);
        }

        err -= dy;
        if (err < 0) {
            y += ystep;
            err += dx;
        }
    }
}