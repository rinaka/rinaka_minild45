; Rotating blades
; note: programmed for the MSX1
; tested in openMSX using C-BIOS
; usage: openmsx -machine C-BIOS_MSX1 -cart <name>

; some useful BIOS functions
GTSTCK:         equ 0x00d5
GTTRIG:         equ 0x00d8
INIT32:         equ 0x006f
LDIRVM:         equ 0x005c
WRTVDP:         equ 0x0087

; BIOS-used variables
BDRCLR:         equ 0xf3eb
BAKCLR:         equ 0xf3ea
FORCLR:         equ 0xf3e9

; VRAM addreses
CLRTAB:         equ 0x2010 ; top 16 entries of the color table
NAMTAB:         equ 0x1800
PATTAB:         equ 0x0400 ; top half of the pattern table
SPRATR:         equ 0x1b00
SPRPAT:         equ 0x3800

; The arrays of data for the blades sprites
; Eight blocks of four bytes (y, x, n, c)
BLDSPR:			equ	0xe000
; Eight blocks of four bytes (min, max, flags, 0)
; flags = adcccsss
; a = axis (0 - y, 1 - x)
; d = direction (0 - add, 1 - subtract)
; ccc = animation counter
; sss = speed (1, 2 or 4)
BLDATR:			equ BLDSPR+32

        org     0x4000

; cartridge header

        dw      0x4241
        dw      main
        ds      12

main:
        di

        im      1
        ld      sp, 0xf380
        
        ; initialize variables
        ld      hl, sprini
        ld      de, BLDSPR
        ld      bc, 64
        ldir

        ; enter graphics mode
        ld      hl, 0x0401
        ld      (BAKCLR), hl
        ld      a, 0x0f
        ld      (FORCLR), a
        call    INIT32
        ld      hl, basclr
        ld      de, CLRTAB
        ld      bc, 16
        call    LDIRVM
        ld      hl, baspat
        ld      de, PATTAB
        ld      bc, 1024
        call    LDIRVM
        ld      hl, basnam
        ld      de, NAMTAB
        ld      bc, 768
        call    LDIRVM
        ld      hl, sprite0
        ld      de, SPRPAT
        ld      bc, 32
        call    LDIRVM
        ld      hl, BLDSPR
        ld      de, SPRATR
        ld      bc, 32
        call    LDIRVM

        ei

mainloop:
		; loop updating the blades
		ld		ix, BLDSPR
		ld		iy, BLDATR
		ld		de, 4
		ld		b, 8
sprupd:	
		; update movement
		ld		a, (iy+2)
		bit		7, a
		jr		nz, moveh
		; vertical movement
		bit		6, a
		jr		nz, goup
		and		7
		add		a, (ix+0)
		ld		(ix+0), a
		cp		(iy+1)
		jr		nz, anim
		jr		flipd
goup:	
		and		7
		ld		c, a
		ld		a, (ix+0)
		sub		c
		ld		(ix+0), a
		cp		(iy+0)
		jr		nz, anim
		jr		flipd
		; horizontal movement
moveh:
		bit		6, a
		jr		nz, goleft
		and		7
		add		a, (ix+1)
		ld		(ix+1), a
		cp		(iy+1)
		jr		nz, anim
		jr		flipd
goleft:	
		and		7
		ld		c, a
		ld		a, (ix+1)
		sub		c
		ld		(ix+1), a
		cp		(iy+0)
		jr		nz, anim
flipd:
		ld		a, (iy+2)
		xor		0x40
		ld		(iy+2), a
anim:
		; update animation frame
		ld		a, (iy+2)
		ld		c, a
		and		0x38
		srl		a
		srl		a
		srl		a
		inc		a
		and		7
		jr		nz, skipanim
		ld		h, a
		ld		a, (ix+2)
		inc		a
		and		3
		ld		(ix+2), a
		ld		a, h
skipanim:
		sla		a
		sla		a
		sla		a
		ld		h, a
		ld		a, 0xc7
		and		c
		or		h
		ld		(iy+2), a
		add		ix, de
		add		iy, de
		; unfortunately the update code got too long,
		; so I cannot use djnz
		ld		a, b
		dec		a
		ld		b, a
		cp		0
		jp		nz, sprupd
		; update sprites in VRAM
        ld      hl, BLDSPR
        ld      de, SPRATR
        ld      bc, 32
        call    LDIRVM
        halt
        jp      mainloop

; initialization data
sprini:
		dm		31, 40, 0, 6
        dm      39, 40, 1, 6
        dm		39, 207, 0, 6
        dm		167, 40, 1, 6
		dm		71, 80, 0, 6
        dm      87, 167, 1, 6
        dm		103, 167, 0, 6
        dm		119, 80, 1, 6
        
        dm		40, 207, 0x81, 0
        dm		39, 159, 0x01, 0
        dm		39, 159, 0x01, 0
        dm		40, 207, 0x81, 0
        dm		80, 167, 0x81, 0
        dm		80, 167, 0xc1, 0
        dm		80, 167, 0xc1, 0
        dm		80, 167, 0x81, 0

; sprite banks
sprite0:    
        dm      0x18, 0x10, 0x18, 0x27, 0xe4, 0x18, 0x08, 0x18
        dm		0x20, 0x42, 0x3c, 0x24, 0x24, 0x3c, 0x42, 0x04
        dm		0x10, 0x10, 0x18, 0xa7, 0xe5, 0x18, 0x08, 0x08
		dm		0x00, 0x42, 0x3d, 0x24, 0x24, 0xbc, 0x42, 0x00

; colors to be copied to the color table
basclr:
        dm      0xc2, 0x6e, 0x31, 0x41, 0x51, 0x61, 0x71, 0x81
        dm      0x11, 0x21, 0x31, 0x41, 0x51, 0x61, 0x71, 0x81

; tiles to be copied to the pattern table
baspat:
        dm      0x44, 0xff, 0x11, 0xff, 0x22, 0xff, 0x88, 0xff
        ds      56, 0xff
        dm      0xee, 0xee, 0x00, 0x77, 0x77, 0x00, 0xee, 0xee
        dm      0x77, 0x77, 0x00, 0xee, 0xee, 0x00, 0x77, 0x77
        dm      0x00, 0x77, 0x77, 0x00, 0x00, 0xee, 0xee, 0x00
        dm      0x00, 0xee, 0xee, 0x00, 0x00, 0x77, 0x77, 0x00
        ds      928, 0xff

; screen layout to be copied to the name table
basnam:
        dm      "  ROTATING BLADES               "
        dm      0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20
        dm      0x20, 0x20, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x20, 0x20
        dm      0x20, 0x20, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x20, 0x20
        dm      0x20, 0x20, 0x88, 0x89, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x88, 0x89, 0x20, 0x20
        dm      0x20, 0x20, 0x8a, 0x8b, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x8a, 0x8b, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x20, 0x20
        dm      0x20, 0x20, 0x88, 0x89, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x88, 0x89, 0x20, 0x20
        dm      0x20, 0x20, 0x8a, 0x8b, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x8a, 0x8b, 0x20, 0x20
        dm      0x20, 0x20, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x88, 0x89, 0x20, 0x20
        dm      0x20, 0x20, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x8a, 0x8b, 0x20, 0x20

; filler for 32kB cartridge
        ds      0c000h - $,0xff
