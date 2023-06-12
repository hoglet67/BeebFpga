    config_reg              = &2FF0

    config_reg_video        = config_reg + 0
    config_reg_hdmi_audio   = config_reg + 1
    config_reg_hdmi_aspect  = config_reg + 2
    config_reg_copro        = config_reg + 3
    config_reg_debug        = config_reg + 4
    config_reg_keydip       = config_reg + 5
    config_reg_ps2_swap     = config_reg + 6

    config_reg_control      = config_reg + 15

    CONTROL_REMAP           = &01
    CONTROL_RESET           = &80

    splash                  = config_reg + &10
    romcheck                = config_reg + &11

    screen_base             = &5800
    num_cols                = 40
    num_rows                = 32

    FLAG_CRC_ERROR          = &01
    FLAG_CONFIG_ERROR       = &02
    FLAG_PAUSE              = &80

    ptr                     = &70
    fcrc                    = &72
    tmpa                    = &74
    flags                   = &75
    acc16                   = &76

    cfg                     = &80
    tmp                     = &82
    src                     = &84
    dst                     = &86

    char                    = &88
    scrn                    = &8A
    scrntmp                 = &8C
    cursor_x                = &8E
    cursor_y                = &8F

    rom_crc_test            = &90
    rom_crc_value_lo        = &A0
    rom_crc_value_hi        = &B0

;; The ROM slot used for config data
   cfg_slot                 = 5

;; The beeb.cfg text is preloaded here
   beeb_cfg_data            = &8000

;; The Spec Next config.ini binary data is loaded here
   spec_cfg_data            = &BF00

; The first 16 bytes contain generic configuration information (taken from
; the Next's config.ini) that the core may optionally take into account
; when starting:
; +0 video timing mode (0..7)
; +1 scandoubler (0=off, 1=on)
; +2 frequency (0=50Hz, 1=60Hz)
; +3 PS/2 mode (0=keyboard, 1=mouse)
; +4 scanline weight (0=off, 1=75%, 2=50%, 3=25%)
; +5 internal speaker (0=disabled, 1=enabled)
; +6 HDMI sound (0=disabled, 1=enabled)
; +7..15 RESERVED
;
    spec_video_timing_mode  = spec_cfg_data + 0
    spec_scandoubler        = spec_cfg_data + 1
    spec_frequency          = spec_cfg_data + 2
    spec_ps2_mode           = spec_cfg_data + 3
    spec_scanline_weight    = spec_cfg_data + 4
    spec_internal_speaker   = spec_cfg_data + 5
    spec_hdmi_audio         = spec_cfg_data + 6
; The next 16 bytes indicate whether the first 16 "userfile" options resulted
; in a file being selected. For each byte, 0 means "not selected" and 1 means
; "selected".
;
; The next 32 bytes contain the null-terminated path of the core
; (eg "/MACHINES/CORENAME",0)
;
; The next 192 bytes are reserved for future use.


org &C000
.start

.splash_image
    incbin "splash2.bin"

org &E800


; ===============================================================================
; Fast CRC (using the 16-bit Atom CRC)
; ===============================================================================

.crcTableLo
    EQUB &00, &68, &D0, &B8, &A0, &C8, &70, &18
    EQUB &40, &28, &90, &F8, &E0, &88, &30, &58
    EQUB &80, &E8, &50, &38, &20, &48, &F0, &98
    EQUB &C0, &A8, &10, &78, &60, &08, &B0, &D8
    EQUB &00, &68, &D0, &B8, &A0, &C8, &70, &18
    EQUB &40, &28, &90, &F8, &E0, &88, &30, &58
    EQUB &80, &E8, &50, &38, &20, &48, &F0, &98
    EQUB &C0, &A8, &10, &78, &60, &08, &B0, &D8
    EQUB &00, &68, &D0, &B8, &A0, &C8, &70, &18
    EQUB &40, &28, &90, &F8, &E0, &88, &30, &58
    EQUB &80, &E8, &50, &38, &20, &48, &F0, &98
    EQUB &C0, &A8, &10, &78, &60, &08, &B0, &D8
    EQUB &00, &68, &D0, &B8, &A0, &C8, &70, &18
    EQUB &40, &28, &90, &F8, &E0, &88, &30, &58
    EQUB &80, &E8, &50, &38, &20, &48, &F0, &98
    EQUB &C0, &A8, &10, &78, &60, &08, &B0, &D8
    EQUB &00, &68, &D0, &B8, &A0, &C8, &70, &18
    EQUB &40, &28, &90, &F8, &E0, &88, &30, &58
    EQUB &80, &E8, &50, &38, &20, &48, &F0, &98
    EQUB &C0, &A8, &10, &78, &60, &08, &B0, &D8
    EQUB &00, &68, &D0, &B8, &A0, &C8, &70, &18
    EQUB &40, &28, &90, &F8, &E0, &88, &30, &58
    EQUB &80, &E8, &50, &38, &20, &48, &F0, &98
    EQUB &C0, &A8, &10, &78, &60, &08, &B0, &D8
    EQUB &00, &68, &D0, &B8, &A0, &C8, &70, &18
    EQUB &40, &28, &90, &F8, &E0, &88, &30, &58
    EQUB &80, &E8, &50, &38, &20, &48, &F0, &98
    EQUB &C0, &A8, &10, &78, &60, &08, &B0, &D8
    EQUB &00, &68, &D0, &B8, &A0, &C8, &70, &18
    EQUB &40, &28, &90, &F8, &E0, &88, &30, &58
    EQUB &80, &E8, &50, &38, &20, &48, &F0, &98
    EQUB &C0, &A8, &10, &78, &60, &08, &B0, &D8

.crcTableHi
    EQUB &00, &01, &02, &03, &05, &04, &07, &06
    EQUB &0B, &0A, &09, &08, &0E, &0F, &0C, &0D
    EQUB &16, &17, &14, &15, &13, &12, &11, &10
    EQUB &1D, &1C, &1F, &1E, &18, &19, &1A, &1B
    EQUB &2D, &2C, &2F, &2E, &28, &29, &2A, &2B
    EQUB &26, &27, &24, &25, &23, &22, &21, &20
    EQUB &3B, &3A, &39, &38, &3E, &3F, &3C, &3D
    EQUB &30, &31, &32, &33, &35, &34, &37, &36
    EQUB &5A, &5B, &58, &59, &5F, &5E, &5D, &5C
    EQUB &51, &50, &53, &52, &54, &55, &56, &57
    EQUB &4C, &4D, &4E, &4F, &49, &48, &4B, &4A
    EQUB &47, &46, &45, &44, &42, &43, &40, &41
    EQUB &77, &76, &75, &74, &72, &73, &70, &71
    EQUB &7C, &7D, &7E, &7F, &79, &78, &7B, &7A
    EQUB &61, &60, &63, &62, &64, &65, &66, &67
    EQUB &6A, &6B, &68, &69, &6F, &6E, &6D, &6C
    EQUB &B4, &B5, &B6, &B7, &B1, &B0, &B3, &B2
    EQUB &BF, &BE, &BD, &BC, &BA, &BB, &B8, &B9
    EQUB &A2, &A3, &A0, &A1, &A7, &A6, &A5, &A4
    EQUB &A9, &A8, &AB, &AA, &AC, &AD, &AE, &AF
    EQUB &99, &98, &9B, &9A, &9C, &9D, &9E, &9F
    EQUB &92, &93, &90, &91, &97, &96, &95, &94
    EQUB &8F, &8E, &8D, &8C, &8A, &8B, &88, &89
    EQUB &84, &85, &86, &87, &81, &80, &83, &82
    EQUB &EE, &EF, &EC, &ED, &EB, &EA, &E9, &E8
    EQUB &E5, &E4, &E7, &E6, &E0, &E1, &E2, &E3
    EQUB &F8, &F9, &FA, &FB, &FD, &FC, &FF, &FE
    EQUB &F3, &F2, &F1, &F0, &F6, &F7, &F4, &F5
    EQUB &C3, &C2, &C1, &C0, &C6, &C7, &C4, &C5
    EQUB &C8, &C9, &CA, &CB, &CD, &CC, &CF, &CE
    EQUB &D5, &D4, &D7, &D6, &D0, &D1, &D2, &D3
    EQUB &DE, &DF, &DC, &DD, &DB, &DA, &D9, &D8


MACRO mirror
{
    LDX #7
.loop
    ASL A
    ROR tmpa
    DEX
    BPL loop
    LDA tmpa
}
ENDMACRO

.fast_crc
{
    PHA
    TXA
    PHA
    TYA
    PHA

    LDA #&00
    STA ptr
    LDA #&80
    STA ptr + 1
    LDA #&00
    STA fcrc
    STA fcrc + 1
    LDY #&00
.fastCRC1
    ;;  crc = (crc >> 8) ^ CRCtbl[(crc & 0xFF)] ^ ((b & 0xff) << 8);
    LDX fcrc
    LDA fcrc + 1
    EOR crcTableLo, X
    STA fcrc
    LDA (ptr),Y
    EOR crcTableHi, X
    STA fcrc + 1

    INY
    BNE fastCRC1
    INC ptr + 1
    LDA ptr + 1
    CMP #&C0
    BNE fastCRC1

;; reverse the result bits to get the standard Atom CRC

    LDA fcrc
    mirror
    PHA
    LDA fcrc + 1
    mirror
    STA fcrc
    PLA
    STA fcrc + 1

    PLA
    TAY
    PLA
    TAX
    PLA
    RTS
}


; ===============================================================================
; Simple VDU drivers
; ===============================================================================

.char_table
 EQUB &00, &00, &00, &00, &00, &00, &00, &00
 EQUB &18, &18, &18, &18, &18, &00, &18, &00
 EQUB &6c, &6c, &6c, &00, &00, &00, &00, &00
 EQUB &36, &36, &7f, &36, &7f, &36, &36, &00
 EQUB &0c, &3f, &68, &3e, &0b, &7e, &18, &00
 EQUB &60, &66, &0c, &18, &30, &66, &06, &00
 EQUB &38, &6c, &6c, &38, &6d, &66, &3b, &00
 EQUB &0c, &18, &30, &00, &00, &00, &00, &00
 EQUB &0c, &18, &30, &30, &30, &18, &0c, &00
 EQUB &30, &18, &0c, &0c, &0c, &18, &30, &00
 EQUB &00, &18, &7e, &3c, &7e, &18, &00, &00
 EQUB &00, &18, &18, &7e, &18, &18, &00, &00
 EQUB &00, &00, &00, &00, &00, &18, &18, &30
 EQUB &00, &00, &00, &7e, &00, &00, &00, &00
 EQUB &00, &00, &00, &00, &00, &18, &18, &00
 EQUB &00, &06, &0c, &18, &30, &60, &00, &00
 EQUB &3c, &66, &6e, &7e, &76, &66, &3c, &00
 EQUB &18, &38, &18, &18, &18, &18, &7e, &00
 EQUB &3c, &66, &06, &0c, &18, &30, &7e, &00
 EQUB &3c, &66, &06, &1c, &06, &66, &3c, &00
 EQUB &0c, &1c, &3c, &6c, &7e, &0c, &0c, &00
 EQUB &7e, &60, &7c, &06, &06, &66, &3c, &00
 EQUB &1c, &30, &60, &7c, &66, &66, &3c, &00
 EQUB &7e, &06, &0c, &18, &30, &30, &30, &00
 EQUB &3c, &66, &66, &3c, &66, &66, &3c, &00
 EQUB &3c, &66, &66, &3e, &06, &0c, &38, &00
 EQUB &00, &00, &18, &18, &00, &18, &18, &00
 EQUB &00, &00, &18, &18, &00, &18, &18, &30
 EQUB &0c, &18, &30, &60, &30, &18, &0c, &00
 EQUB &00, &00, &7e, &00, &7e, &00, &00, &00
 EQUB &30, &18, &0c, &06, &0c, &18, &30, &00
 EQUB &3c, &66, &0c, &18, &18, &00, &18, &00
 EQUB &3c, &66, &6e, &6a, &6e, &60, &3c, &00
 EQUB &3c, &66, &66, &7e, &66, &66, &66, &00
 EQUB &7c, &66, &66, &7c, &66, &66, &7c, &00
 EQUB &3c, &66, &60, &60, &60, &66, &3c, &00
 EQUB &78, &6c, &66, &66, &66, &6c, &78, &00
 EQUB &7e, &60, &60, &7c, &60, &60, &7e, &00
 EQUB &7e, &60, &60, &7c, &60, &60, &60, &00
 EQUB &3c, &66, &60, &6e, &66, &66, &3c, &00
 EQUB &66, &66, &66, &7e, &66, &66, &66, &00
 EQUB &7e, &18, &18, &18, &18, &18, &7e, &00
 EQUB &3e, &0c, &0c, &0c, &0c, &6c, &38, &00
 EQUB &66, &6c, &78, &70, &78, &6c, &66, &00
 EQUB &60, &60, &60, &60, &60, &60, &7e, &00
 EQUB &63, &77, &7f, &6b, &6b, &63, &63, &00
 EQUB &66, &66, &76, &7e, &6e, &66, &66, &00
 EQUB &3c, &66, &66, &66, &66, &66, &3c, &00
 EQUB &7c, &66, &66, &7c, &60, &60, &60, &00
 EQUB &3c, &66, &66, &66, &6a, &6c, &36, &00
 EQUB &7c, &66, &66, &7c, &6c, &66, &66, &00
 EQUB &3c, &66, &60, &3c, &06, &66, &3c, &00
 EQUB &7e, &18, &18, &18, &18, &18, &18, &00
 EQUB &66, &66, &66, &66, &66, &66, &3c, &00
 EQUB &66, &66, &66, &66, &66, &3c, &18, &00
 EQUB &63, &63, &6b, &6b, &7f, &77, &63, &00
 EQUB &66, &66, &3c, &18, &3c, &66, &66, &00
 EQUB &66, &66, &66, &3c, &18, &18, &18, &00
 EQUB &7e, &06, &0c, &18, &30, &60, &7e, &00
 EQUB &7c, &60, &60, &60, &60, &60, &7c, &00
 EQUB &00, &60, &30, &18, &0c, &06, &00, &00
 EQUB &3e, &06, &06, &06, &06, &06, &3e, &00
 EQUB &18, &3c, &66, &42, &00, &00, &00, &00
 EQUB &00, &00, &00, &00, &00, &00, &00, &ff
 EQUB &1c, &36, &30, &7c, &30, &30, &7e, &00
 EQUB &00, &00, &3c, &06, &3e, &66, &3e, &00
 EQUB &60, &60, &7c, &66, &66, &66, &7c, &00
 EQUB &00, &00, &3c, &66, &60, &66, &3c, &00
 EQUB &06, &06, &3e, &66, &66, &66, &3e, &00
 EQUB &00, &00, &3c, &66, &7e, &60, &3c, &00
 EQUB &1c, &30, &30, &7c, &30, &30, &30, &00
 EQUB &00, &00, &3e, &66, &66, &3e, &06, &3c
 EQUB &60, &60, &7c, &66, &66, &66, &66, &00
 EQUB &18, &00, &38, &18, &18, &18, &3c, &00
 EQUB &18, &00, &38, &18, &18, &18, &18, &70
 EQUB &60, &60, &66, &6c, &78, &6c, &66, &00
 EQUB &38, &18, &18, &18, &18, &18, &3c, &00
 EQUB &00, &00, &36, &7f, &6b, &6b, &63, &00
 EQUB &00, &00, &7c, &66, &66, &66, &66, &00
 EQUB &00, &00, &3c, &66, &66, &66, &3c, &00
 EQUB &00, &00, &7c, &66, &66, &7c, &60, &60
 EQUB &00, &00, &3e, &66, &66, &3e, &06, &07
 EQUB &00, &00, &6c, &76, &60, &60, &60, &00
 EQUB &00, &00, &3e, &60, &3c, &06, &7c, &00
 EQUB &30, &30, &7c, &30, &30, &30, &1c, &00
 EQUB &00, &00, &66, &66, &66, &66, &3e, &00
 EQUB &00, &00, &66, &66, &66, &3c, &18, &00
 EQUB &00, &00, &63, &6b, &6b, &7f, &36, &00
 EQUB &00, &00, &66, &3c, &18, &3c, &66, &00
 EQUB &00, &00, &66, &66, &66, &3e, &06, &3c
 EQUB &00, &00, &7e, &0c, &18, &30, &7e, &00
 EQUB &0c, &18, &18, &70, &18, &18, &0c, &00
 EQUB &18, &18, &18, &00, &18, &18, &18, &00
 EQUB &30, &18, &18, &0e, &18, &18, &30, &00
 EQUB &31, &6b, &46, &00, &00, &00, &00, &00
 EQUB &ff, &ff, &ff, &ff, &ff, &ff, &ff, &ff



.oswrch
{
    PHA
    TXA
    PHA
    TYA
    PHA

    TSX
    LDA &103, X

    CMP #&08
    BNE not_8
    JSR cursor_left
    JMP exit
.not_8
    CMP #&09
    BNE not_9
    JSR cursor_right
    JMP exit
.not_9
    CMP #&0A
    BNE not_a
    JSR cursor_down
    JMP exit
.not_a
    CMP #&0B
    BNE not_b
    JSR cursor_up
    JMP exit
.not_b
    CMP #&0D
    BNE not_d
    JSR cursor_sol
    JMP exit

.not_d
    AND #&7F
    CMP #&20
    BCC exit
    SBC #&20

    ; Compute the address of the character in the character table
    LDX #0
    STX char+1
    ASL A
    ROL char+1
    ASL A
    ROL char+1
    ASL A
    ROL char+1
    ADC #<char_table
    STA char
    LDA char+1
    ADC #>char_table
    STA char+1

    ; Compute the screen address of the character
    ; screen_base + 320 * cursor_y + 8 * cursor_x

    ; 8 * cursor_x => scrntmp
    LDA #0
    STA scrntmp+1
    LDA cursor_x
    ASL A
    ROL scrntmp+1
    ASL A
    ROL scrntmp+1
    ASL A
    ROL scrntmp+1
    STA scrntmp

    ; 320 * cursor_y => scrn
    LDA #0
    STA scrn
    LDA cursor_y
    STA scrn+1
    LSR A
    ROR scrn
    LSR A
    ROR scrn
    CLC
    ADC scrn+1
    STA scrn+1

    ; scrn = scrn + scrntmp + screen_base
    CLC
    LDA #<screen_base
    ADC scrntmp
    ADC scrn
    STA scrn
    LDA #>screen_base
    ADC scrntmp+1
    ADC scrn+1
    STA scrn+1

    ; Copy the character
    LDY #7
.copy
    LDA (char), Y
    STA (scrn), Y
    DEY
    BPL copy

    JSR cursor_right

.exit
    PLA
    TAY
    PLA
    TAX
    PLA
    RTS
}

.cursor_sol
{
    LDA #0
    STA cursor_x
    RTS
}

.cursor_left
{
    LDA cursor_x
    BNE normal
    LDA #num_cols-1
    STA cursor_x
    JMP cursor_up
.normal
    DEC cursor_x
    RTS
}

.cursor_right
{
    LDA cursor_x
    CMP #num_cols-1
    BNE normal
    LDA #0
    STA cursor_x
    JMP cursor_down
.normal
    INC cursor_x
    RTS
}

.cursor_up
{
    LDA cursor_y
    BNE normal
    LDA #num_rows-1
    STA cursor_y
    RTS
.normal
    DEC cursor_y
    RTS
}

.cursor_down
{
    LDA cursor_y
    CMP #num_rows-1
    BNE normal
    LDA #0
    STA cursor_y
    RTS
.normal
    INC cursor_y
    RTS
}

.print_hex
{
    PHA
    PHA
    LSR A
    LSR A
    LSR A
    LSR A
    JSR hex1
    PLA
    JSR hex1
    PLA
    RTS
.hex1
    AND #&F
    CMP #&A
    BCC toascii
    ADC #&6
.toascii
    ADC #'0'
    JMP oswrch
}

.print_string
{

    PLA
    STA tmp
    PLA
    STA tmp+1
    LDY #0
.loop
    INC tmp
    BNE nocarry
    INC tmp+1
.nocarry
    LDA (tmp),Y
    BMI exit
    JSR oswrch
    JMP loop
.exit
    JMP (tmp)
}



.process_spec_cfg
{
    ; Copy the PS/2 Mode setting
    LDA spec_ps2_mode
    STA config_reg_ps2_swap

    ; Copy the HDMI Audio setting
    LDA spec_hdmi_audio
    STA config_reg_hdmi_audio

    ; Map the Video related settings as best we can

    ; Video Mode = 7 suggests HDMI is being used (scan doubler ignored)
    LDA spec_video_timing_mode
    CMP #7
    BEQ video_mode_1

    ; Scan Doubler = 0 suggests RGB is being
    LDA spec_scandoubler
    BEQ video_mode_0

    ; Otherwise try VGA (which should also output on HDMI)

; VGA (sub-optional for HDMI)
.video_mode_3
    LDA #3
    BNE exit

; VGA (sub-optional for HDMI)
.video_mode_2
    LDA #2
    BNE exit

; HDMI (sub-optimal for VGA)
.video_mode_1
    LDA #1
    BNE exit

; sRGB
.video_mode_0
    LDA #0

.exit
    STA config_reg_video
    RTS
}

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

    ;; Set the cursor to the top left
    LDA #0
    STA cursor_x
    STA cursor_y

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
    STA acc16
    STA acc16+1

.loop
    LDA (cfg), Y
    JSR hex_digit
    BCS exit

    INY

    ASL acc16
    ROL acc16+1
    ASL acc16
    ROL acc16+1
    ASL acc16
    ROL acc16+1
    ASL acc16
    ROL acc16+1
    ORA acc16
    STA acc16

    JMP loop

.exit
    LDA acc16
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
    EQUB "ps2_mode",    0, 6
    EQUB "splash",      0, &10
    EQUB "romcheck",    0, &11
    EQUB "cmos",        0, &80
    EQUB "crc",         0, &C0
    EQUB 0,             0, 0

.process_beeb_cfg
{

    LDA #<beeb_cfg_data
    STA cfg
    LDA #>beeb_cfg_data
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
    BPL normal_key     ; b7=1 indicates the cmos or crc keys

    JSR read_hex       ; read a further number XX (cmosXX=YY)
    ORA keys_table,X   ; keep b7/b6 set

.normal_key
    TAX                ; and move to X
    JSR skip_spc
    CMP #'='
    BNE skip_to_eol
    INY
    JSR skip_spc
    JSR read_hex

    CPX #&80
    BCC config_write

    CPX #&C0
    BCS crc_write

    PHA
    TXA
    CLC
    ADC #&0E           ; CMOS[00] is stored in RTC[0E]
    TAX
    PLA
    JSR cmos_write_data
    JMP skip_to_eol

.crc_write
    PHA
    TXA
    AND #&3F
    TAX
    PLA
    LDA acc16
    STA rom_crc_value_lo, X
    LDA acc16+1
    STA rom_crc_value_hi, X
    LDA #1
    STA rom_crc_test, X
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
    BEQ next_line
    CMP #&0D
    BEQ next_line
    INC cfg
    BNE skip_to_eol_loop
    INC cfg+1
    BNE skip_to_eol_loop

.next_line
    JMP start_line

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
    LDY #<screen_base
    STY dst
    LDA #>splash_image
    STA src+1
    LDA #>screen_base
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

.validate_config
{
    LDA #cfg_slot
    STA &FE30
    LDA #2
    STA cursor_x
    LDA #27
    STA cursor_y
    JSR print_string
    EQUB "beeb.cfg config "
    NOP
    LDY #0
    STY tmp
    LDA #&80
    STA tmp+1
.loop
    LDA (tmp),Y
    BMI config_error
    INY
    BNE loop
    INC tmp+1
    LDA tmp+1
    CMP #&BF
    BNE loop
    JSR print_string
    EQUB "clean"
    NOP
    RTS
.config_error
    JSR print_string
    EQUB "dirty"
    NOP
    LDA flags
    ORA #FLAG_CONFIG_ERROR
    STA flags
    RTS
}

.init_crc_checks
{
    LDA #0

    ; Clear the ROM test table
    LDY #15
.loop1
    STA rom_crc_test, Y
    DEY
    BPL loop1

    ; Page on ROM 8 (that's split RAM/ROM)
    LDY #8
    STY &FE30

    ; Clear the RAM region of ROM 8
    LDY #0
.loop2
    STA &B600, Y
    STA &B700, Y
    STA &B800, Y
    STA &B900, Y
    STA &BA00, Y
    STA &BB00, Y
    STA &BC00, Y
    STA &BD00, Y
    STA &BE00, Y
    STA &BF00, Y
    DEY
    BNE loop2

    ; Page on ROM 8 (that's split RAM/ROM)
    LDY #cfg_slot
    STY &FE30

    RTS
}

.perform_crc_checks
{
    ; Checksum the ROM data

    ; Set the cursor to just below the splash screen
    LDA #2
    STA cursor_x
    LDA #16
    STA cursor_y

    JSR print_string
    EQUB "Checking ROM CRCs...."
    NOP

    ;    0123456789012345678901234567890123456789
    ; 16 | Checking ROM CRCs...                 |
    ; 17 |                                      |
    ; 18 | 00:CRC=0000:OK     08:CRC=0000:OK    |
    ; 19 | 01:CRC=0000:FAIL   09:CRC=0000:FAIL  |
    ; 20 | 02:CRC=0000:OK     0A:CRC=0000:OK    |
    ; 21 | 03:CRC=0000:OK     0B:CRC=0000:OK    |
    ; 22 | 04:CRC=0000:OK     0C:CRC=0000:OK    |
    ; 23 | 05:--------:--     0D:--------:--    |
    ; 24 | 06:CRC=0000:OK     0E:CRC=0000:OK    |
    ; 25 | 07:CRC=0000:OK     0F:CRC=0000:OK    |
    ; 26 |                                      |
    ; 27 | beeb.cfg config clean                |
    ; 28 |                                      |
    ; 29 | Version: 20200505_1954 abcdef12?     |
    ; 30 |                                      |
    ; 31 +--------------------------------------+

    LDX #0
.loop

    ; Calculate Cursor X
    TXA
    AND #8
    BNE l1
    LDA #2
    BNE l2
.l1
    LDA #21
.l2
    STA cursor_x

    ; Calculate Cursor Y
    TXA
    AND #7
    CLC
    ADC #18
    STA cursor_y

    TXA
    JSR print_hex

    LDA rom_crc_test, X
    BEQ unused_rom

    JSR print_string
    EQUB ":CRC="
    NOP

    STX &FE30
    JSR fast_crc

    LDA fcrc+1
    JSR print_hex
    LDA fcrc
    JSR print_hex

    LDA fcrc
    CMP rom_crc_value_lo, X
    BNE crc_fail
    LDA fcrc+1
    CMP rom_crc_value_hi, X
    BEQ crc_ok

.crc_fail
    LDA flags
    ORA #FLAG_CRC_ERROR
    STA flags

    JSR print_string
    EQUB ":FAIL"
    NOP
    JMP next_rom

.crc_ok
    JSR print_string
    EQUB ":OK"
    NOP
    JMP next_rom

.unused_rom
    JSR print_string
    EQUB ":--------:--"
    NOP

.next_rom
    INX
    CPX #16
    BNE loop
    RTS
}

.wipe_sideways_ram
{
    LDA #&00
    TAY
    LDX #&04
.loop1
    STX &FE30
.loop2
    STA &8000, Y
    DEY
    BNE loop2
    INX
    CPX #8
    BNE loop1
    RTS
}

.rst_handler
    LDX #&00
    STX flags

    ; Clear the first 4 pages of RAM
    TXA
.ram_clear_loop
    STA &0000, X
    STA &0100, X
    STA &0200, X
    STA &0300, X
    DEX
    BNE ram_clear_loop

    DEX
    TXS

    ; Map the sideways RAM into slots 4-7
    LDA #&00
    STA config_reg_control

    ; Wipe the first page of each sideways RAM bank, as these get corrupted across
    ; reconfigurations, which causes the system to hang.
    JSR wipe_sideways_ram

    ; Map the OS Rom and beeb.cfg file into slots 4-7
    LDA #CONTROL_REMAP
    STA config_reg_control

    ; Page in the slot with the config data
    LDA #cfg_slot
    STA &FE30

    ; Process the Spec Next Config.ini
    JSR process_spec_cfg

    ; Default to showing the splash screen
    LDA #30
    STA splash

    ; Clear the crc test flags
    JSR init_crc_checks

    ; Parse and process the Beeb beeb.cfg file
    JSR process_beeb_cfg

    LDA splash
    PHA
    LDA romcheck
    PHA

    JSR copy_splash

    LDA #4
    JSR mode

    ; Update the version
    LDA #2
    STA cursor_x
    LDA #29
    STA cursor_y
    JSR print_string
INCLUDE "version.asm"
    NOP

    PLA
    BEQ skip_crc_checks

    ; Validate the CRCs of the ROMs
    JSR perform_crc_checks

    ; Currently this just looks for chars >= 0x80
    JSR validate_config

.skip_crc_checks

    ;; Detect the presence or not of PiTubeDirect by probing &FEF0
    ;; this reads from the external tube without asserting
    LDA #2
    STA cursor_x
    LDA #28
    STA cursor_y
    JSR print_string
    EQUB "External PiTube "
    NOP
    ; Probe the external tube databus value
    ; (ntube is supressed in config mode)
    LDA &FEE0
    PHA
    CMP #&55
    BEQ pitube_detected
    JSR print_string
    EQUB "not "
    NOP
.pitube_detected
    JSR print_string
    EQUB "detected "
    NOP
    LDA #'('
    JSR oswrch
    PLA
    JSR print_hex
    LDA #')'
    JSR oswrch

    PLA
    TAX

    ; Delay for a short period
.delay_loop
    JSR delay100ms
    DEX
    BPL delay_loop

    ; Has a key been pressed?
    LDA &FE4D
    AND #&01
    BEQ continue

    ; Yes, set the pause flag
    LDA #FLAG_PAUSE
    ORA flags
    STA flags

    ; Clear the interrupt flag
    LDA &FE41

.continue

    ; Are any flags set?
    LDA flags
    BEQ reset

    ; Yes, then wait for another key press
.key_loop
    LDA &FE4D
    AND #&01
    BEQ key_loop

.reset
    LDA #CONTROL_RESET
    STA config_reg_control

.forever
    JMP forever

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
