; Rooms of Doom
; a small game designed for Mini-LD #45
;
; note: programmed for the MSX1
; tested in openMSX using C-BIOS
; usage: openmsx -machine C-BIOS_MSX1 -cart <name>

; some useful BIOS functions
FILVRM:			equ 0x0056
GTSTCK:         equ 0x00d5
GTTRIG:         equ 0x00d8
INIT32:         equ 0x006f
INIGRP:			equ	0x0072
LDIRVM:         equ 0x005c
WRTVDP:         equ 0x0087

; BIOS-used variables
BDRCLR:         equ 0xf3eb
BAKCLR:         equ 0xf3ea
FORCLR:         equ 0xf3e9

; VRAM addresses
; for the "tiles"
CLRTAB:         equ 0x2010 ; top 16 entries of the color table
NAMTAB:         equ 0x1800 ; address of the name table (i.e. screen map)
PATTAB:         equ 0x0400 ; top half of the pattern table
; for the sprites
SPRATR:         equ 0x1b00
SPRPAT:         equ 0x3800

; Variables
VARBASE:        equ 0xe000
; Address of the level map
level_map:      equ VARBASE
; Array of data for sprites
; Each sprite takes 4 bytes (y, x, pattern, color)
; First we have the player
player_sprite:  equ level_map+2
; Then we have the key
key_sprite:     equ player_sprite+4
; And the room exit
exit_sprite:    equ key_sprite+4
; Lastly, we have up to 12 blades
blade_sprites:  equ exit_sprite+4
; Player movement state (0 = stopped, > 0 = moving)
player_state:   equ blade_sprites+48
; Player movement direction (1 = up, 3 = right, 5 = down, 7 = left)
player_dir:     equ player_state+1
; Number of active blades
has_key:        equ player_dir+1
num_blades:     equ has_key+1
; Array of data for the blades
; Each data block has four bytes (min, max, flags, 0)
; flags = adcccsss
; a = axis (0 - y, 1 - x)
; d = direction (0 - add, 1 - subtract)
; ccc = animation counter
; sss = speed (1, 2 or 4)
blade_data:     equ num_blades+1

        org     0x4000

        ; cartridge header
        dw      0x4241
        dw      main
        ds      12
        
        ; entry point
main:
        ; basic setup
        di

        im      1
        ld      sp, 0xf380

		; enter graphics mode for the title screen
        ld      hl, 0x0101
        ld      (BAKCLR), hl
        ; white foreground (for text)
        ld      a, 0x0f
        ld      (FORCLR), a
        call    INIGRP
        ; load the title
		ld	hl, title_screen
		ld	de, 2048
		ld	bc, 2048
		call	LDIRVM
		ld	hl,	0x2800
		ld	bc, 2048
		ld	a, 0x81
		call	FILVRM

		ei

		; loop until space is pressed
title_loop:
		xor		a
		call	GTTRIG
		cp		0xff
		jr		z, start_game
		jr		title_loop
		
start_game:
		di
		
        ; enter 32x24 color text mode
        ; black border and background
        ld      hl, 0x0101
        ld      (BAKCLR), hl
        ; white foreground (for text)
        ld      a, 0x0f
        ld      (FORCLR), a
        call    INIT32
        
        ; load the "tiles"
        ld      hl, tile_colors
        ld      de, CLRTAB
        ld      bc, 16
        call    LDIRVM
        ld      hl, tile_patterns
        ld      de, PATTAB
        ld      bc, 64
        call    LDIRVM

        ; load the sprites
        ld      hl, spr_patterns
        ld      de, SPRPAT
        ld      bc, 56
        call    LDIRVM
        
        ; set up level 1
        ; map
        ld      hl, level1_map
        ld      de, NAMTAB
        ld      bc, 768
        call    LDIRVM
        ; variables
        ld      hl, level1_vars
        ld      de, VARBASE
        ld      bc, 114
        ldir
        ; update sprites
        ld      hl, player_sprite
        ld      de, SPRATR
        ld      bc, 60
        call    LDIRVM
        
        ei

        ; main game loop
mainloop:
        ; check input and move player
        ld      a, (player_state)
        cp      0
        jr      nz, skip_input
        call    check_input
        cp      0
skip_input:
        call    nz, move_player
        ; move the rotating blades
        call    move_blades
        ; check for player-key and player-exit collision
        ld      a, (has_key)
        cp      0
        jr      z, skip_exit
        call    check_exit_col
        jr      skip_key
skip_exit:
        call    check_key_col
skip_key:
        ; check for player-blades collision
        call    check_blades_col
        ; update sprites in VRAM
        di
        ld      hl, player_sprite
        ld      de, SPRATR
        ld      bc, 60
        call    LDIRVM
        ei
        ; halt for next interrupt
        halt
        jp      mainloop
    
; check "joystick 0" (actually, the arrow keys)
; if a direction is detected, update player variables to
; cause movement
; input: nothing
; output: A - 0 if no move, 8 otherwise
; modifies flags, A, B, H, L
check_input:
        xor     a
        call    GTSTCK
        cp      1
        jr      nz, tst_mv_right
        ld      d, a
        ld      a, (player_sprite)
        sub     a, 7
        ld      h, a
        ld      a, (player_sprite+1)
        ld      l, a
        call    check_wall
        jr      z, save_input
        jr      no_input
tst_mv_right:
        cp      3
        jr      nz, tst_mv_down
        ld      d, a
        ld      a, (player_sprite)
        ; NOTE: must increment Y coordinate because sprites are
        ; misaligned to the tiles by 1 pixel (see VDP specs)
        inc     a
        ld      h, a
        ld      a, (player_sprite+1)
        add     a, 8
        ld      l, a
        call    check_wall
        jr      z, save_input
        jr      no_input
tst_mv_down:
        cp      5
        jr      nz, tst_mv_left
        ld      d, a
        ld      a, (player_sprite)
        add     a, 9
        ld      h, a
        ld      a, (player_sprite+1)
        ld      l, a
        call    check_wall
        jr      z, save_input
        jr      no_input
tst_mv_left:
        cp      7
        jr      nz, no_input
        ld      d, a
        ld      a, (player_sprite)
        inc     a
        ld      h, a
        ld      a, (player_sprite+1)
        sub     a, 8
        ld      l, a
        call    check_wall
        jr      z, save_input
no_input:
        xor     a
        ret
save_input:
        ld      a, d
        ld      (player_dir), a
        ld      a, 8
        ld      (player_state), a
        ret

; check if there is a wall at a given screen-coordinate
; input: H - y coordinate, L - x coordinate
; output: A - tile at coordinates, Z flag set if there is NO wall
check_wall:
        ld      b, 0
        ld      c, l
        ; calculating the row address
        ; we want to divide y by eight and then multiply it
        ; by 32. This would mean three right shifts followed
        ; by five left shifts. We can instead do an AND 11111000
        ; to cut the three LSBs and then do two left-shifts.
        ; NOTE: we must do it in 16-bits otherwise the result
        ; might overflow. This can be accomplished with add hl, hl
        ld      a, h
        and     0xf8
        ld      h, 0
        ld      l, a
        add     hl, hl
        add     hl, hl
        ; now we add the column divided by eight to the row address
        srl     c
        srl     c
        srl     c
        add     hl, bc
        ; lastly, add the level map offset
        ld      bc, (level_map)
        add     hl, bc
        ; and load the byte at that address
        ld      a, (hl)
        ; compare to 0x80 which is our 'empty' tile
        cp      0x80
        ret
        
; update player when moving
; input: A - current value of player_state
; output: nothing
move_player:
        dec     a
        ld      (player_state), a
        ld      a, (player_dir)
        cp      1
        jr      nz, tst_dir_right
        ld      a, (player_sprite)
        dec     a
        ld      (player_sprite), a
        ret
tst_dir_right:
        cp      3
        jr      nz, tst_dir_down
        ld      a, (player_sprite+1)
        inc     a
        ld      (player_sprite+1), a
        ret
tst_dir_down: 
        cp      5
        jr      nz, tst_dir_left
        ld      a, (player_sprite)
        inc     a
        ld      (player_sprite), a
        ret
tst_dir_left:
        cp      7
        ret     nz
        ld      a, (player_sprite+1)
        dec     a
        ld      (player_sprite+1), a
        ret

; update position and animation of rotating blades
move_blades:
		; loop updating the blades
		ld		ix, blade_sprites
		ld		iy, blade_data
		ld		de, 4
        ld      a, (num_blades)
		ld		b, a
blade_loop:	
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
		jp		nz, blade_loop
        ret

; test if player and exit have collided
; output: A - 0 no collision / 1 - collision
check_exit_col:
        ld      a, (player_sprite)
        srl     a
        srl     a
        srl     a
        ld      b, a
        ld      a, (exit_sprite)
        srl     a
        srl     a
        srl     a
        cp      b
        jr      nz, no_exit_col
        ld      a, (player_sprite+1)
        srl     a
        srl     a
        srl     a
        ld      b, a
        ld      a, (exit_sprite+1)
        srl     a
        srl     a
        srl     a
        cp      b
        jr      nz, no_exit_col
        ld      a, 4
        ld      (player_sprite+3), a
        ld      a, 1
        ret
no_exit_col:        
        ld      a, 0
        ret

; test if player and key have collided
check_key_col:
        ld      a, (player_sprite)
        srl     a
        srl     a
        srl     a
        ld      b, a
        ld      a, (key_sprite)
        srl     a
        srl     a
        srl     a
        cp      b
        ret     nz
        ld      a, (player_sprite+1)
        srl     a
        srl     a
        srl     a
        ld      b, a
        ld      a, (key_sprite+1)
        srl     a
        srl     a
        srl     a
        cp      b
        ret     nz
        ld      a, 1
        ld      (has_key), a
        ld      a, 200
        ld      (key_sprite), a
        ld      a, 10
        ld      (player_sprite+3), a
        ret

; test if player and one of the blades have collided
; output: A - 0 no collision / 1 - collision
check_blades_col:
		; loop testing each blade
		ld		ix, blade_sprites
		ld		de, 4
        ld      a, (player_sprite)
        srl     a
        srl     a
        srl     a
        ld      l, a
        ld      a, (player_sprite+1)
        srl     a
        srl     a
        srl     a
        ld      h, a
        ld      a, (num_blades)
		ld		b, a
blade_col_loop:
        ld      a, (ix+0)
        srl     a
        srl     a
        srl     a
        cp      l
        jr      nz, skip_bc_tst
        ld      a, (ix+1)
        srl     a
        srl     a
        srl     a
        cp      h
        jr      nz, skip_bc_tst
        ld      a, 6
        ld      (player_sprite+3), a
        ld      a, 1
        ret
skip_bc_tst:
        add     ix, de
        djnz
        ld      a, 0
        ret

; include the title screen binary data
title_screen:
		incbin "image.bin"
        
; colors to be copied to the color table
tile_colors:
        dm      0xd0, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f
        dm      0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f, 0x1f

; tiles to be copied to the pattern table
tile_patterns:
        ds      8, 0x00
        dm      0xff, 0x81, 0xfd, 0x85, 0xa1, 0xbf, 0x81, 0xff
        dm      0xff, 0x81, 0xbf, 0xa1, 0x85, 0xfd, 0x81, 0xff
        dm      0xff, 0xa1, 0xad, 0xa5, 0xa5, 0xb5, 0x85, 0xff
        dm      0xff, 0x85, 0xb5, 0xa5, 0xa5, 0xad, 0xa1, 0xff
        dm      0xff, 0x81, 0xbd, 0xa5, 0xa5, 0xbd, 0x81, 0xff
        dm      0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa
        ds      8, 0x00

; sprite banks
spr_patterns:
        ; blades - I use sprites 0-3 so that I can use a simple "and 3"
        ; to constrain the animation loop...
        dm      0x18, 0x10, 0x18, 0x27, 0xe4, 0x18, 0x08, 0x18
        dm		0x20, 0x42, 0x3c, 0x24, 0x24, 0x3c, 0x42, 0x04
        dm		0x10, 0x10, 0x18, 0xa7, 0xe5, 0x18, 0x08, 0x08
		dm		0x00, 0x42, 0x3d, 0x24, 0x24, 0xbc, 0x42, 0x00
        ; player
        dm      0x3c, 0x7e, 0xdb, 0xff, 0xbd, 0xdb, 0x66, 0x3c
        ; key
        dm      0x00, 0x60, 0x90, 0x9f, 0x9f, 0x93, 0x63, 0x00
        ; exit
        dm      0xff, 0xc3, 0xa5, 0x99, 0x99, 0xa5, 0xc3, 0xff

; level layout
level1_vars:
        ; block of data to fill the variables, starting from level_map
        dw      level1_map
        dm      103, 32, 4, 11
        dm      159, 64, 5, 14
        dm      39, 216, 6, 2
        dm      71, 64, 0, 8
        dm      87, 80, 0, 8
        dm      103, 96, 0, 8
        dm      119, 112, 0, 8
        dm      79, 136, 0, 8
        dm      95, 152, 0, 8
        dm      111, 168, 0, 8
        dm      127, 184, 0, 8
        dm      200, 0, 0, 0 ; inactive blades are hidden below the screen (y > 190)
        dm      200, 0, 0, 0
        dm      200, 0, 0, 0
        dm      200, 0, 0, 0
        dm      0, 0, 0
        dm      8
        dm      71, 135, 0x01, 0
        dm      71, 135, 0x01, 0
        dm      71, 135, 0x01, 0
        dm      71, 135, 0x01, 0
        dm      136, 191, 0x81, 0
        dm      136, 191, 0x81, 0
        dm      136, 191, 0x81, 0
        dm      136, 191, 0x81, 0
        dm      0, 0, 0, 0
        dm      0, 0, 0, 0
        dm      0, 0, 0, 0
        dm      0, 0, 0, 0

level1_map:
        ; block of data to fill the VRAM name table
        ; note: the map should be made of characters 0x80 (empty) and above.
        dm      "  LEVEL 1                       "
        dm      "                                "
        dm      0x80, 0x80, 0x85, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x85, 0x80, 0x80
        dm      0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80
        dm      0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80
        dm      0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80
        dm      0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80
        dm      0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80
        dm      0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x85, 0x80, 0x80
        dm      0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80
        dm      0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80
        dm      0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80
        dm      0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80
        dm      0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80
        dm      0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80
        dm      0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80
        dm      0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80
        dm      0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80
        dm      0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x85, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x84, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x85, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80
        dm      0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80
        dm      0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80
        dm      0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x83, 0x80, 0x80
        dm      0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x84, 0x80, 0x80
        dm      0x80, 0x80, 0x85, 0x81, 0x82, 0x81, 0x85, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x81, 0x82, 0x85, 0x80, 0x80
        
; filler for 32kB cartridge
        ds      0c000h - $,0xff
