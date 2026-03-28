#include <avr/io.h>
#include <util/delay.h>
#include "video.h"




int main() {

video_config(0,1);
_delay_ms(500);

vga_clear_screen(BLACK);
vga_fillRect(0, 0, 620, 32, BLUE);

    vga_setTextFont(2);
    vga_setTextSize(2);
    vga_setTextColor(WHITE, 0x0000);

    vga_printAt("Mje", 10, 5, GREEN, BLUE, 2);

    const char* menuName;
    menuName = "MENU";

    vga_printAt(menuName, 430, 5, WHITE, DARKGREY, 2);

    // 3. Cornice Area Traccia (400x240)
    vga_drawRect(4, 32, 402, 242, WHITE);

    vga_drawLine(10, 400, 600, 50, GREEN);


//test_fill();
    while(1) {
        // Rimani qui
    }
    return 0;
}