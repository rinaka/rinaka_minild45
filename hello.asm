; A "Hello, World" cartridge
; note: programmed for the MSX1
; tested in openMSX using C-BIOS
; usage: openmsx -machine C-BIOS_MSX1 -cart <name>

; some useful BIOS functions
CHGET:		equ	0x009f
CHPUT:		equ	0x00a2
KILBUF:		equ	0x0156
INITXT:		equ	0x006c

		org	0x4000

; cartridge header
		dw	0x4241
		dw	main
		ds	12
main:
		di
		im	1
		ld	sp, 0xf380
		ei
		call 	INITXT

; print our message on the screen
		ld	hl, message
textout:
		ld	a, (hl)
		call	CHPUT
		cp	0
		jr	z, mainloop
		inc	hl
		jr	textout

		call	KILBUF
; this will simply loop, printing any keys that are pressed
mainloop:
		call	CHGET
		call	CHPUT
		jr	mainloop

message:
		dm	"Hello, World!", 13, 10, 0

; filler for 32kB cartridge
		ds	0xc000 - $, 0xff

