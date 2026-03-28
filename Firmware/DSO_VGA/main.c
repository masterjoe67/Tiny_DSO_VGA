

#include <avr/io.h>
#include <util/delay.h>
#include <stdio.h>
#include "Peripheral/video.h"
#include "Peripheral/input.h"
#include "Peripheral/uart.h"
#include "Peripheral/leds.h"
#include "scope.h"

// ------------------------------------------------
// Main
// ------------------------------------------------
int main(void) {
    uart_init(19200);
    uart_print("\r\nBoot AVR + ST7798S\r\n");

    uart_print("Inizializzo display...\r\n");

    keypad_init();
    LED_Init();
 
    _delay_ms(1000);
    video_config(0, 1);

    vga_clear_screen(WHITE);

    vga_setTextFont(2);
    vga_setTextSize(1);
    vga_setTextColor(WHITE, 0x0000);
_delay_ms(1000);
    scope_main();

    return 0;
}
