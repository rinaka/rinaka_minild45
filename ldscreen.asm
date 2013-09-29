; Loading a 256x64 graphics block to the screen
; note: programmed for the MSX1
; tested in openMSX using C-BIOS
; usage: openmsx -machine C-BIOS_MSX1 -cart <name>

; some useful BIOS functions
LDIRVM:		equ	0x005c
INIGRP:		equ	0x0072
FILVRM:		equ 0x0056

; BIOS-used variables
BDRCLR:		equ	0xf3eb
BAKCLR:		equ	0xf3ea
FORCLR:		equ	0xf3e9


		org	0x4000

; cartridge header

		dw	0x4241
		dw	main
		ds	12

main:
		di

		im	1
		ld	sp, 0xf380

		; enter graphics mode
		ld	hl, 0x0401
		ld	(BAKCLR), hl
		ld	a, 0x04
		ld	(FORCLR), a
		call	INIGRP
		ld	hl, graphix
		ld	de, 0
		ld	bc, 2048
		call	LDIRVM
		ld	hl,	0x2000
		ld	bc, 6*1024
		ld	a, 0xf1
		call	FILVRM
		
		ei

mainloop:
		; pause until an interrupt occurs
		halt
		jr	mainloop

; initialization data
graphix:
		incbin "image.bin"

; filler for 32kB cartridge
		ds 	0c000h - $,0xff

