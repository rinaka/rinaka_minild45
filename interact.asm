; A first attempt at interactivity
; note: programmed for the MSX1
; tested in openMSX using C-BIOS
; usage: openmsx -machine C-BIOS_MSX1 -cart <name>

; some useful BIOS functions
GTSTCK:		equ	0x00d5
GTTRIG:		equ	0x00d8
LDIRVM:		equ	0x005c
INIGRP:		equ	0x0072

; BIOS-used variables
BDRCLR:		equ	0xf3eb
BAKCLR:		equ	0xf3ea
FORCLR:		equ	0xf3e9

SPRATR:		equ	0x1b00
SPRPAT:		equ	0x3800

; Our program variables
spry:		equ	0xe000
sprx:		equ	spry+1
sprn:		equ	sprx+1
sprc:		equ	sprn+1

		org	0x4000

; cartridge header

		dw	0x4241
		dw	main
		ds	12

main:
		di

		im	1
		ld	sp, 0xf380
		
		; initialize variables
		ld	hl, sprini
		ld	de, spry
		ld	bc, 4
		ldir

		; enter graphics mode
		ld	hl, 0x0401
		ld	(BAKCLR), hl
		ld	a, 0x04
		ld	(FORCLR), a
		call	INIGRP
		ld	hl, sprite0
		ld	de, SPRPAT
		ld	bc, 2048
		call	LDIRVM
		ld	hl, spry
		ld	de, SPRATR
		ld	bc, 4
		call	LDIRVM

		ei

mainloop:
		xor	a
		call	GTSTCK
		ld	b, 1
		cp	b
		jr	nz, chkright
		ld	a, (spry)
		dec	a
		ld	(spry), a
		jr	updspr
chkright:	
		inc	b
		inc	b
		cp	b
		jr	nz, chkdown
		ld	a, (sprx)
		inc	a
		ld	(sprx), a
		jr	updspr
chkdown:	
		inc	b
		inc	b
		cp	b
		jr	nz, chkleft
		ld	a, (spry)
		inc	a
		ld	(spry), a
		jr	updspr
chkleft:
		inc	b
		inc	b
		cp	b
		jr	nz, mainloop
		ld	a, (sprx)
		dec	a
		ld	(sprx), a

updspr:		
		ld	a, 0
		ld	hl, spry
		ld	de, SPRATR
		ld	bc, 4
		call	LDIRVM

		; pause until an interrupt occurs
		halt
		jr	mainloop

; initialization data
sprini:
		dm	100, 0, 0, 10

; sprite banks
sprite0:	
		dm	0x3c, 0x7e, 0xdb, 0xff, 0xbd, 0xdb, 0x66, 0x3c
		ds	2040, 0xff

; filler for 32kB cartridge
		ds 	0c000h - $,0xff

