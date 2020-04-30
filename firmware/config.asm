    config_reg        = &2FF0
    config_reg_reset  = &2FFF
    splash            = &3000

    config_file       = &C000

    cfg               = &80
    tmp               = &82
    src               = &84
    dst               = &86

org &C000
.start

    ;; The beeb.cfg is preloaded here

org &D000

.splash_image
    incbin "splash.bin"

org &F800

.modebase

.mode012
    EQUB &7F, &50, &62, &28, &26, &00, &20, &23
    EQUB &00, &07, &6F, &08, &06, &00, &06, &00

.mode3
    EQUB &7F, &50, &62, &28, &1E, &02, &19, &1C
    EQUB &00, &09, &6F, &09, &08, &00, &08, &00

.mode45
    EQUB &3F, &28, &31, &24, &26, &00, &20, &23
    EQUB &00, &07, &6F, &08, &0B, &00, &0B, &00

.mode6
    EQUB &3F, &28, &31, &24, &1E, &02, &19, &1C
    EQUB &00, &09, &6F, &09, &0C, &00, &0C, &00

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

    RTS
}

.hex_digit
{
    CMP #'0'
    BCC bad
    CMP #'9'+1
    BCC good
    AND #&DF
    CMP #'A'
    BCC bad
    CMP #'F'+1
    BCS bad
    SBC #'A'-'9'-2
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

.read_hex
{

    LDA #0
    STA tmp

.loop
    LDA (cfg), Y
    JSR hex_digit
    BCS exit

    INY
    ASL tmp
    ASL tmp
    ASL tmp
    ASL tmp
    ORA tmp
    STA tmp

    JMP loop

.exit
    LDA tmp
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

.skip_spc
{
    DEY
.loop
    INY
    LDA (cfg), Y
    CMP #' '
    BEQ loop
    RTS
}

.keys_table
    EQUB "video",       0, 0
    EQUB "hdmi_audio",  0, 1
    EQUB "hdmi_aspect", 0, 2
    EQUB "copro",       0, 3
    EQUB "debug",       0, 4
    EQUB "keydip",      0, 5
    EQUB "splash",      0, &10
    EQUB "cmos",        0, &80
    EQUB 0,             0, 0

.parse_config
{

    LDA #<config_file
    STA cfg
    LDA #>config_file
    STA cfg+1

.start_line

    ; Skip any whitespace (including newlines)
    JSR skip_whitespace
    ; (cfg) points to first non-whitespace, and A holds the value

    ; Check for a comment line
    CMP #';'
    BEQ skip_to_eol

    LDX #&00  ; index into keys table

.loop1
    LDY #&FF  ; index into config file

    ; run out of keys?
    LDA keys_table, X
    BEQ skip_to_eol

    ; try to match the current key
    DEX
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

    ; skip the terminator
    INX
    ; skip the reg index
    INX
    ; match the next key
    JMP loop1

.match

    INX
    LDA keys_table, X  ; Config Register Index
    TAX

    BPL normal_key     ; b7=1 indicates the cmos key
    JSR read_hex       ; read a further number XX (cmosXX=YY)
    CLC
    ADC #&0E           ; CMOS[00] is stored in RTC[0E]
    ORA #&80           ; keep b7 set
    TAX                ; and move to X
.normal_key
    JSR skip_spc
    CMP #'='
    BNE skip_to_eol
    INY
    JSR skip_spc
    JSR read_hex

    CPX #&80
    BCC config_write

    JSR cmos_write_data
    JMP skip_to_eol

.config_write
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
    BEQ start_line
    CMP #&0D
    BEQ start_line
    INC cfg
    BNE skip_to_eol_loop
    INC cfg+1
    BNE skip_to_eol_loop

.end_of_file
    RTS
}


; Strobe the address in X in
.cmos_strobe_addr
{
    LDA #&02
    STA &FE40
    LDA #&82
    STA &FE40
    LDA #&FF
    STA &FE43
    TXA
    AND #&3F   ; masking bit 7,6
    STA &FE4F
    LDA #&C2
    STA &FE40
    LDA #&42
    STA &FE40
    RTS
}

; Write the data in A to the CMOS address in X
.cmos_write_data
{
    PHA
    JSR cmos_strobe_addr
    LDA #&41
    STA &FE40
    LDA #&FF
    STA &FE43
    LDA #&4A
    STA &FE40
    PLA
    STA &FE4F
    LDA #&42
    STA &FE40
    LDA #&02
    STA &FE40
    LDA #&00
    STA &FE43
    RTS
}

.copy_splash
{
    LDY #<splash_image
    STY src
    LDY #&00
    STY dst
    LDA #>splash_image
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

    ; Default to showing the splash screen
    LDA #30
    STA splash

    JSR parse_config

    LDA splash
    BEQ reset

    PHA

    JSR copy_splash

    LDA #4
    JSR mode

    PLA
    TAX
.loop
    JSR delay100ms
    DEX
    BNE loop

.reset
    LDA #&00
    STA config_reg_reset

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

; *CONFIGURE FILE 9

; Read CMOS [0x13]

; 00.440021 : Mem Wr Watch hit at 9908 writing FE40:02 latch(1) rtc_rnw = 0
; 00.440027 : Mem Wr Watch hit at 990D writing FE40:82
; 00.440033 : Mem Wr Watch hit at 9912 writing FE43:FF DDRA = output
; 00.440037 : Mem Wr Watch hit at 9915 writing FE4F:13 Address = 1E
; 00.440043 : Mem Wr Watch hit at 991A writing FE40:C2
; 00.440049 : Mem Wr Watch hit at 991F writing FE40:42

; 00.440061 : Mem Wr Watch hit at 98BE writing FE40:49
; 00.440065 : Mem Wr Watch hit at 98C1 writing FE43:00 DDRA = input
; 00.440071 : Mem Wr Watch hit at 98C6 writing FE40:4A
; 00.440081 : Mem Wr Watch hit at 98CE writing FE40:42
; 00.440087 : Mem Wr Watch hit at 98D3 writing FE40:02
; 00.440091 : Mem Wr Watch hit at 98D6 writing FE43:00

; Write CMOS [0x13]

; 00.440134 : Mem Wr Watch hit at 9908 writing FE40:02
; 00.440140 : Mem Wr Watch hit at 990D writing FE40:82
; 00.440146 : Mem Wr Watch hit at 9912 writing FE43:FF DDRA = output
; 00.440150 : Mem Wr Watch hit at 9915 writing FE4F:13
; 00.440156 : Mem Wr Watch hit at 991A writing FE40:C2
; 00.440162 : Mem Wr Watch hit at 991F writing FE40:42

; 00.440174 : Mem Wr Watch hit at 98EB writing FE40:41
; 00.440180 : Mem Wr Watch hit at 98F0 writing FE43:FF DDRA = output
; 00.440186 : Mem Wr Watch hit at 98F5 writing FE40:4A
; 00.440190 : Mem Wr Watch hit at 98F8 writing FE4F:C9 <<<< Write
; 00.440199 : Mem Wr Watch hit at 98CE writing FE40:42
; 00.440205 : Mem Wr Watch hit at 98D3 writing FE40:02
; 00.440209 : Mem Wr Watch hit at 98D6 writing FE43:00

; Strobe Address Code

; 9906 : A9 02    : LDA #$02
; 9908 : 8D 40 FE : STA $FE40
; 990B : A9 82    : LDA #$82
; 990D : 8D 40 FE : STA $FE40
; 9910 : A9 FF    : LDA #$FF
; 9912 : 8D 43 FE : STA $FE43
; 9915 : 8E 4F FE : STX $FE4F
; 9918 : A9 C2    : LDA #$C2
; 991A : 8D 40 FE : STA $FE40
; 991D : A9 42    : LDA #$42
; 991F : 8D 40 FE : STA $FE40
; 9922 : 60       : RTS

; Read Code

; 98B7 : 08       : PHP
; 98B8 : 78       : SEI
; 98B9 : 20 06 99 : JSR $9906
; 98BC : A9 49    : LDA #$49
; 98BE : 8D 40 FE : STA $FE40
; 98C1 : 9C 43 FE : STZ $FE43
; 98C4 : A9 4A    : LDA #$4A
; 98C6 : 8D 40 FE : STA $FE40
; 98C9 : AC 4F FE : LDY $FE4F
; 98CC : A9 42    : LDA #$42
; 98CE : 8D 40 FE : STA $FE40
; 98D1 : A9 02    : LDA #$02
; 98D3 : 8D 40 FE : STA $FE40
; 98D6 : 9C 43 FE : STZ $FE43
; 98D9 : 28       : PLP
; 98DA : 98       : TYA
; 98DB : 60       : RTS

; Write CMOS [0x13]

; 98E4 : 08       : PHP
; 98E5 : 78       : SEI
; 98E6 : 20 06 99 : JSR $9906
; 98E9 : A9 41    : LDA #$41
; 98EB : 8D 40 FE : STA $FE40
; 98EE : A9 FF    : LDA #$FF
; 98F0 : 8D 43 FE : STA $FE43
; 98F3 : A9 4A    : LDA #$4A
; 98F5 : 8D 40 FE : STA $FE40
; 98F8 : 8C 4F FE : STY $FE4F
; 98FB : 80 CF    : BRA $98CC

; 98CC : A9 42    : LDA #$42
; 98CE : 8D 40 FE : STA $FE40
; 98D1 : A9 02    : LDA #$02
; 98D3 : 8D 40 FE : STA $FE40
; 98D6 : 9C 43 FE : STZ $FE43
; 98D9 : 28       : PLP
; 98DA : 98       : TYA
; 98DB : 60       : RTS
