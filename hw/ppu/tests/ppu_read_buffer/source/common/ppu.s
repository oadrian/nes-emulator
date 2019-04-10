; PPU utilities

zp_res ppu_not_present

; Sets PPUADDR to w
; Preserved: X, Y
.macro set_ppuaddr w
	bit PPUSTATUS
	setb PPUADDR,>w
	setb PPUADDR,<w
.endmacro


; Delays by no more than n scanlines
.macro delay_scanlines n
	.if CLOCK_RATE <> 1789773
		.error "Currently only supports NTSC"
	.endif
	delay ((n)*341)/3
.endmacro


; Waits for VBL then disables PPU rendering.
; Preserved: A, X, Y
disable_rendering:
	pha
	jsr wait_vbl_optional
	setb PPUMASK,0
	pla
	rts


; Fills first nametable with $00
; Preserved: Y
clear_nametable:
	ldx #$20
	bne clear_nametable_

clear_nametable2:
	ldx #$24
clear_nametable_:
	lda #0
	jsr fill_screen_
	
	; Clear pattern table
	ldx #64
:       sta PPUDATA
	dex
	bne :-
	rts


; Fills screen with tile A
; Preserved: A, Y
fill_screen:
	ldx #$20
	bne fill_screen_
	
; Same as fill_screen, but fills other nametable
fill_screen2:
	ldx #$24
fill_screen_:
	stx PPUADDR
	ldx #$00
	stx PPUADDR
	ldx #240
:       sta PPUDATA
	sta PPUDATA
	sta PPUDATA
	sta PPUDATA
	dex
	bne :-
	rts


; Fills palette with $0F
; Preserved: Y
clear_palette:
	set_ppuaddr $3F00
	ldx #$20
	lda #$0F
:       sta PPUDATA
	dex
	bne :-


; Fills OAM with $FF
; Preserved: Y
clear_oam:
	lda #$FF
; Fills OAM with A
; Duration: 6 + (6*4+3) * (256/4) - 1 + 12 = 1745 cycles, including JSR
; Preserved: A, Y
fill_oam:
	ldx #0		; 2
	stx SPRADDR	; 4
:       .repeat 8
	sta SPRDATA	; 4
	dex		; 2
	.endrepeat
	bne :-		; 3
	rts


; Initializes wait_vbl_optional. Must be called before
; using it.
init_wait_vbl:
	; Wait for VBL flag to be set, or ~60000
	; clocks (2 frames) to pass
	ldy #24
	ldx #1
	bit PPUSTATUS
:       bit PPUSTATUS
	bmi @set
	dex
	bne :-
	dey
	bpl :-
@set:
	; Be sure flag didn't stay set (in case
	; PPUSTATUS always has high bit set)
	tya
	ora PPUSTATUS
	sta ppu_not_present
	rts

; Same as wait_vbl, but returns immediately if PPU
; isn't working or doesn't support VBL flag
; Preserved: A, X, Y
wait_vbl_optional:
	bit ppu_not_present
	bmi :++ 
	; FALL THROUGH

; Clears VBL flag then waits for it to be set.
; Preserved: A, X, Y
wait_vbl:
	bit PPUSTATUS
:       bit PPUSTATUS
	bpl :-
:       rts
