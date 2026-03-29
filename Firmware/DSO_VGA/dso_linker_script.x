/* Script per Tiny_DSO_VGA - ATmega128 (32K Flash, 16K RAM) */
OUTPUT_FORMAT("elf32-avr","elf32-avr","elf32-avr")
OUTPUT_ARCH(avr:51)

__TEXT_REGION_ORIGIN__ = DEFINED(__TEXT_REGION_ORIGIN__) ? __TEXT_REGION_ORIGIN__ : 0;
__TEXT_REGION_LENGTH__ = 32K;
__DATA_REGION_ORIGIN__ = DEFINED(__DATA_REGION_ORIGIN__) ? __DATA_REGION_ORIGIN__ : 0x800100;
__DATA_REGION_LENGTH__ = 0x4000; /* 16K RAM */
__EEPROM_REGION_LENGTH__ = 4K;

/* Stack alla fine dei 16KB fisici */
__stack = 0x8040ff;

MEMORY
{
  text   (rx)   : ORIGIN = __TEXT_REGION_ORIGIN__, LENGTH = __TEXT_REGION_LENGTH__
  data   (rw!x) : ORIGIN = __DATA_REGION_ORIGIN__, LENGTH = __DATA_REGION_LENGTH__
  eeprom (rw!x) : ORIGIN = 0x810000, LENGTH = __EEPROM_REGION_LENGTH__
  fuse      (rw!x) : ORIGIN = 0x820000, LENGTH = 1K
  lock      (rw!x) : ORIGIN = 0x830000, LENGTH = 1K
  signature (rw!x) : ORIGIN = 0x840000, LENGTH = 1K
}

SECTIONS
{
  .text :
  {
    *(.vectors)
    KEEP(*(.vectors))
    
    *(.progmem.gcc*)
    *(.progmem*)
    
    . = ALIGN(2);
    *(.trampolines)
    *(.trampolines*)
    
    *(.init0) KEEP (*(.init0))
    *(.init1) KEEP (*(.init1))
    *(.init2) KEEP (*(.init2))
    *(.init3) KEEP (*(.init3))
    *(.init4) KEEP (*(.init4))
    *(.init5) KEEP (*(.init5))
    *(.init6) KEEP (*(.init6))
    *(.init7) KEEP (*(.init7))
    *(.init8) KEEP (*(.init8))
    *(.init9) KEEP (*(.init9))
    
    *(.text)
    . = ALIGN(2);
    *(.text.*)
    . = ALIGN(2);
    
    *(.fini9) KEEP (*(.fini9))
    *(.fini8) KEEP (*(.fini8))
    *(.fini7) KEEP (*(.fini7))
    *(.fini6) KEEP (*(.fini6))
    *(.fini5) KEEP (*(.fini5))
    *(.fini4) KEEP (*(.fini4))
    *(.fini3) KEEP (*(.fini3))
    *(.fini2) KEEP (*(.fini2))
    *(.fini1) KEEP (*(.fini1))
    *(.fini0) KEEP (*(.fini0))
    
    *(.jumptables)
    *(.jumptables*)
    *(.lowtext)
    
    _etext = . ;
  } > text

  .data :
  {
     PROVIDE (__data_start = .) ;
    *(.data)
    *(.data*)
    *(.rodata)
    *(.rodata*)
    *(.gnu.linkonce.d*)
    . = ALIGN(2);
     _edata = . ;
     PROVIDE (__data_end = .) ;
  } > data AT> text

  .bss :
  {
     PROVIDE (__bss_start = .) ;
    *(.bss)
    *(.bss*)
    *(COMMON)
     PROVIDE (__bss_end = .) ;
  } > data

  __data_load_start = LOADADDR(.data);
  __data_load_end = __data_load_start + SIZEOF(.data);

  /* Debug sections rimosse per brevità, ma il linker le gestirà comunque */
}

