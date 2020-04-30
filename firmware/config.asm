    config_reg = &2FF0

    config_reg_vid         = config_reg + 0
    config_reg_hdmi_audio  = config_reg + 1
    config_reg_hdmi_aspect = config_reg + 2
    config_reg_copro       = config_reg + 3
    config_reg_debug       = config_reg + 4
    config_reg_keyb_dip    = config_reg + 5
    config_reg_reset       = config_reg + 15


    config_file = &C000
;   config_slot = &01

    src = &80
    dst = &82

    cfg = &84
    tmp = &86

org &C000
.start

org &C800

.splash
    INCBIN "splash.bin"

org &F000

.modebase

.mode012
    EQUB &7F, &50, &62, &28, &26, &00, &20, &23
    EQUB &01, &07, &67, &08, &06, &00, &06, &00

.mode3
    EQUB &7F, &50, &62, &28, &1E, &02, &19, &1C
    EQUB &01, &09, &67, &09, &08, &00, &08, &00

.mode45
    EQUB &3F, &28, &31, &24, &26, &00, &20, &23
    EQUB &01, &07, &67, &08, &0B, &00, &0B, &00

.mode6
    EQUB &3F, &28, &31, &24, &1E, &02, &19, &1C
    EQUB &01, &09, &67, &09, &0C, &00, &0C, &00

.mode7
    EQUB &3F, &28, &33, &24, &1E, &02, &19, &1C
    EQUB &93, &12, &72, &13, &28, &00, &28, &00


.modelatchb4
    EQUB &0C,&0C,&0C,&04,&04,&04,&0C,&0C

.modelatchb5
    EQUB &0D,&0D,&0D,&05,&0D,&0D,&05,&05

.modetable
    EQUB mode012-modebase
    EQUB mode012-modebase
    EQUB mode012-modebase
    EQUB mode3-modebase
    EQUB mode45-modebase
    EQUB mode45-modebase
    EQUB mode6-modebase
    EQUB mode7-modebase

.palettebase

.palette1bpp
    EQUB &80, &90, &A0, &B0, &C0, &D0, &E0, &F0
    EQUB &07, &17, &27, &37, &47, &57, &67, &77

.palette2bpp
    EQUB &A0, &B0, &E0, &F0, &84, &94, &C4, &D4
    EQUB &26, &36, &66, &76, &07, &17, &47, &57

.palette4bpp
    EQUB &F8, &E9, &DA, &CB, &BC, &AD, &9E, &8F
    EQUB &70, &61, &52, &43, &34, &25, &16, &07

.palettetable
    EQUB palette1bpp-palettebase
    EQUB palette2bpp-palettebase
    EQUB palette4bpp-palettebase
    EQUB palette1bpp-palettebase
    EQUB palette1bpp-palettebase
    EQUB palette2bpp-palettebase
    EQUB palette1bpp-palettebase
    EQUB palette1bpp-palettebase

.videoula
    EQUB &9c, &d8, &f4, &9c, &88, &c4, &88, &4b

.soundinit
    EQUB &9F, &82, &3F, &BF
    EQUB &A1, &3F, &DF, &C0
    EQUB &3F, &FF, &E0, &00

;; Delay 100ms or ~200000 cycles
.delay100ms
{
    TXA
    PHA
    TYA
    PHA
    LDX #156   ;; 200000/1280
    LDY #0
.loop
    DEY        ;; 2 * 256
    BNE loop   ;; 3 * 256 = 1280
    DEX
    BNE loop
    PLA
    TAY
    PLA
    TAX
    RTS
}

.writeSoundByte
{
    PHA
    LDA #&FF
    STA &FE43
    PLA
    STA &FE4F
    LDA #&00
    STA &FE40
    LDA #&08
    STA &FE40
    RTS
}

.mode
{
    ;; Stack the mode
    PHA

    ;; Initialize System VIA
    LDA #&0F
    STA &FE42

    ;; Initialize addressable latch
    LDX #&0F
.latchloop
    STX &FE40
    DEX
    CPX #&07
    BNE latchloop


    ;; Set Screen Base
    PLA
    PHA
    TAX
    LDA modelatchb4,X
    STA &FE40
    LDA modelatchb5,X
    STA &FE40

    ;; Initialize SN76489
    LDX #&00
.soundloop
    LDA soundinit,X
    BEQ sounddone
    JSR writeSoundByte
    INX
    BNE soundloop
.sounddone

    ;; Initialiaze 6845
    PLA
    PHA
    TAY
    LDX modetable, Y
    LDY #&00
.modeloop
    STY &FE00
    LDA modebase, X
    STA &FE01
    INX
    INY
    CPY #&10
    BNE modeloop

    ;; Initialize Video ULA
    PLA
    PHA
    TAX
    LDA videoula, X
    STA &FE20

    ;; PLA
    PLA
    TAY
    LDX palettetable, Y
    LDY #&00
.paletteloop
    LDA palettebase, X
    STA &FE21
    INX
    INY
    CPY #&10
    BNE paletteloop

    ;; Start a ^G beep
    LDA #&92
    JSR writeSoundByte
    LDA #&8F
    JSR writeSoundByte
    LDA #&0E
    JSR writeSoundByte

    LDX #5
.beeploop
    JSR delay100ms
    DEX
    BNE beeploop

    ;; Stop the ^G sound
    LDA #&9F
    JSR writeSoundByte
    JSR writeSoundByte
    JSR writeSoundByte

    RTS
}


.keys_table
    EQUB "video",       0, 0
    EQUB "hdmi_aspect", 0, 1
    EQUB "hdmi_audio",  0, 2
    EQUB "copro",       0, 3
    EQUB "debug",       0, 4
    EQUB "keydip",      0, 5
    EQUB 0,             0, 0

.hex_digit
{
    CMP #'0'
    BCC bad
    CMP #'9'+1
    BCC good
    SBC #'A'-'9'-1
    CMP #'0'+&10
    BCS bad
.good
    AND #&0F
    CLC
    RTS
.bad
    SEC
    RTS
}

.skip_whitespace
{
    LDY #&00
.loop
    LDA (cfg), Y
    CMP #' '
    BEQ skip
    CMP #&0A
    BEQ skip
    CMP #&0D
    BEQ skip
    RTS
.skip
    INC cfg
    BNE loop
    INC cfg+1
    BNE loop
}

.parse_config
{

    LDA #<config_file
    STA cfg
    LDA #>config_file
    STA cfg+1

.start_line

    ; Skip any whitespace (including newlines)
    JSR skip_whitespace
    ; (cfg) points to first non-w

    ; Check for a comment line
    CMP #';'
    BEQ skip_to_eol

    LDX #&FF  ; index into keys table

.loop1
    LDY #&FF  ; index into config file

    ; run out of keys?
    LDA keys_table + 1, X
    BEQ skip_to_eol

    ; try to match the cirrent key
.loop2
    INX
    INY
    LDA keys_table, X
    BEQ match
    CMP (cfg), Y
    BEQ loop2

    ; skip to the end of key
.loop3
    INX
    LDA keys_table, X
    BNE loop3

    ; skip the 00 terminator
    INX
    ; match the next key
    JMP loop1

.skip_spc1
    INY
.match
    LDA (cfg), Y
    CMP #' '
    BEQ skip_spc1
    CMP #'='
    BNE skip_to_eol

    ;; Prepare the result
    LDA #0
    STA tmp

.skip_spc2
    INY
    LDA (cfg), Y
    CMP #' '
    BEQ skip_spc2

.hex_loop
    JSR hex_digit
    BCS write_config_reg

    ASL tmp
    ASL tmp
    ASL tmp
    ASL tmp
    ORA tmp
    STA tmp

    INY
    LDA (cfg), Y
    JMP hex_loop

.write_config_reg
    INX
    LDA keys_table, X  ; Config Register Index
    TAX
    LDA tmp
    STA config_reg, X

.skip_to_eol
    TYA
    LDY #&00
    CLC
    ADC cfg
    STA cfg
    BCC skip_to_eol_loop
    INC cfg+1

.skip_to_eol_loop
    LDA (cfg), Y
    BEQ end_of_file
    CMP #&0A
    BEQ next_line
    CMP #&0D
    BEQ next_line
    INC cfg
    BNE skip_to_eol_loop
    INC cfg+1
    BNE skip_to_eol_loop

.end_of_file
    RTS

.next_line
    JMP start_line
}

.copy_splash
{
    LDY #<splash
    STY src
    LDY #&00
    STY dst
    LDA #>splash
    STA src+1
    LDA #&58
    STA dst+1

.loop
    LDA (src),Y
    STA (dst),Y
    INY
    BNE loop
    INC src+1
    INC dst+1
    BPL loop
    RTS
}

.rst_handler
{
    LDX #&FF
    TXS

;   LDA #config_slot
;   STA &FE30

    JSR parse_config

;   LDA #&01
;   STA config_reg_vid
;   LDA #&00
;   STA config_reg_hdmi_audio
;   LDA #&00
;   STA config_reg_hdmi_aspect
;   LDA #&01
;   STA config_reg_copro
;   LDA #&01
;   STA config_reg_debug
;   LDA #&00
;   STA config_reg_keyb_dip

    JSR copy_splash

    LDA #4
    JSR mode

    LDX #20
.loop
    JSR delay100ms
    DEX
    BNE loop

; LDA #&00

; STA config_reg_reset

.forever
    JMP forever
}

.irq_handler
.nmi_handler
    RTI

org &FFFA

    equw nmi_handler
    equw rst_handler
    equw irq_handler

.end

SAVE "config.rom",start, end
