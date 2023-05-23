; (c) Dominic Beesley 2023
; a simple mos rom to exercise the PSRAM of the tangnano9k
; this replaces the regular MOS/BOOT rom and reads and writes a few 
; addresses in PSRAM

		.setcpu "6502X"

vec_nmi		:=	$D00

		.ZEROPAGE

		.CODE

mos_handle_res:

	; tricky test rom prolg
	sei
	cld

	ldx	#$FF
	txs

	ldx	#5
@1:	txa
	sta	$200,X
	dex
	bne	@1

	ldx	#5
@2:	lda	$200,X
	dex
	bne	@2

here:	jmp	here

mos_handle_irq:
		rti

		.SEGMENT "VECTORS"
hanmi:  .addr   vec_nmi                         ; FFFA 00 0D                    ..
hares:  .addr   mos_handle_res                  ; FFFC CD D9                    ..
hairq:  .addr   mos_handle_irq                  ; FFFE 1C DC                    ..

		.END
