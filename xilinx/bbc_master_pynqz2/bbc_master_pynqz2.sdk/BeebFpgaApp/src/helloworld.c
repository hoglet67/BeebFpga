/******************************************************************************
 *
 * Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Use of the Software is limited solely to applications:
 * (a) running on a Xilinx device, or
 * (b) that interact with a Xilinx device through a bus or interconnect.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of the Xilinx shall not be used
 * in advertising or otherwise to promote the sale, use or other dealings in
 * this Software without prior written authorization from Xilinx.
 *
 ******************************************************************************/

/*
 * BeebFPGA Application
 *
 * - UART0/UART1 cross connection for ICE Debugger
 * - USB Host Keyboard Handling
 */

#include <stdio.h>
#include <inttypes.h>
#include <string.h>
#include "xil_exception.h"
#include "xparameters.h"
#include "platform.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xscugic.h"
#include "xgpiops.h"
#include "xuartps.h"
#include "ulpi.h"

#define UART_BUFFER_SIZE 32

int myhelp;
XScuGic_Config *IntcConfig;
XScuGic INTCInst;

int status;
int currentTD = 0;

#define QTD_TERMINATOR ((qtd_type *)1)

#define QH_TERMINATOR ((qh_type *)1)

#define QH_LINK(p) ((qh_type *)(((u32) p) | 2))

enum {
	ST_INITIAL,
	ST_RESET,
	ST_SET_ADDRESS,
	ST_DELAY,
	ST_SET_CONFIGURATION,
	ST_SETUP_PERIODIC,
	ST_PERIODIC,
};


typedef struct qtd_struct {
	struct qtd_struct *next;
	struct qtd_struct *altnext;
	u32 token;
	u32 *buffer;
	u32 *buffer1;
	u32 *buffer2;
	u32 *buffer3;
	u32 *buffer4;
} qtd_type;

typedef struct qh_struct {
	struct qh_struct *qh_link;
	u32 qh_endpt1;
	u32 qh_endpt2;
	qtd_type *current_qtd;
	qtd_type qtd;
} qh_type;


void state_machine();

// AXI Registers that implement the 128-bit keyboard matrix
#define GPIO_REG0          0x41200000
#define GPIO_REG1          0x41200008
#define GPIO_REG2          0x41210000
#define GPIO_REG3          0x41210008

// USB0 Periperal Registers
#define USB0_GPTIMER0LD    0xE0002080
#define USB0_GPTIMER0CTRL  0xE0002084
#define USB0_CMD           0xE0002140
#define USB0_ISR           0xE0002144
#define USB0_IER           0xE0002148
#define USB0_LISTBASE      0xE0002154
#define USB0_ASYNCLISTADDR 0xE0002158
#define USB0_VIEWPORT      0xE0002170
#define USB0_PORTSCR1      0xE0002184
#define USB0_MODE          0xE00021A8

// Fixed USB Async Buffers, used for device setup phase
// TODO: Place these in un-cached RAM, or add cache control
#define USB_ASYNC_QH       ((qh_type  *)0x300000)
#define USB_ASYNC_QTD      ((qtd_type *)0x300040)
#define USB_ASYNC_DATA0    ((u32 *)0x301000)
#define USB_ASYNC_DATA1    ((u32 *)0x302000)
#define NUM_QTD            0x10

// Fixed USB Periodic Buffers, used for periodic device polling
// TODO: Place these in un-cached RAM, or add cache control
#define USB_LISTBASE       ((qh_type **)0x304000)
#define USB_PERIODIC_QH    ((qh_type  *)0x304040)
#define USB_PERIODIC_QH1   ((qh_type  *)0x304080)
#define USB_PERIODIC_QH2   ((qh_type  *)0x3040C0)
#define USB_PERIODIC_QTD1  ((qtd_type *)0x304100)
#define USB_PERIODIC_QTD2  ((qtd_type *)0x304120)
#define USB_PERIODIC_DATA  ((u32      *)0x305000)

struct ulpi_regs *ulpi = (struct ulpi_regs *)0;

struct ulpi_viewport ulpi_vp = {USB0_VIEWPORT, 0};

static const char * ulpi_reg_names[] = {
	"vendor_id_low",
	"vendor_id_high",
	"product_id_low",
	"product_id_high",
	"function_ctrl",
	"function_ctrl_set",
	"function_ctrl_clear",
	"iface_ctrl",
	"iface_ctrl_set",
	"iface_ctrl_clear",
	"otg_ctrl",
	"otg_ctrl_set",
	"otg_ctrl_clear",
	"usb_ie_rising",
	"usb_ie_rising_set",
	"usb_ie_rising_clear",
	"usb_ie_falling",
	"usb_ie_falling_set",
	"usb_ie_falling_clear",
	"usb_int_status",
	"usb_int_latch",
	"debug",
	"scratch",
	"scratch_set",
	"scratch_clear",
	"carkit_ctrl",
	"carkit_ctrl_set",
	"carkit_ctrl_clear",
	"carkit_int_delay",
	"carkit_ie",
	"carkit_ie_set",
	"carkit_ie_clear",
	"carkit_int_status",
	"carkit_int_latch",
	"carkit_pulse_ctrl",
	"carkit_pulse_ctrl_set",
	"carkit_pulse_ctrl_clear",
	"transmit_pos_width",
	"transmit_neg_width",
	"recv_pol_recovery"
};

char *to_binary(u8 n) {
	static char ret[10];
	for (int i = 0; i < 8; i++) {
		ret[7 - i] = '0' + ((n >> i) & 1);
	}
	return ret;
}

void dump_ulpi() {
	printf("****************************************\n");
	printf("ULPI Registers\n");
	for (u8 i = 0; i < 0x28; i++) {
		u8 val = (u8) ulpi_read(&ulpi_vp, &ulpi->vendor_id_low + i);
		printf("ulpi[%02x]:%24s = %02x (%s)\n", i, ulpi_reg_names[i], val, to_binary(val));
	}
}

void scheduleTimer(int usec) {
	//set timer value
	Xil_Out32(USB0_GPTIMER0LD, usec);
	//reload timer
	Xil_Out32(USB0_GPTIMER0CTRL, 0x40000000);
	Xil_Out32(USB0_GPTIMER0CTRL, 0x80000000);
}

// Map from USB Key Code to BBC Keyboard Matrix
// - BBC values 0..7 are Column 0
// - BBC values 8..15 are Column 1
// - etc

static const int8_t bbc_map[] = {
   -1, // 00 Reserved (no event indicated)
   -1, // 01 Keyboard ErrorRollOver
   -1, // 02 Keyboard POSTFail
   -1, // 03 Keyboard ErrorUndefined
   12, // 04 Keyboard a and A
   38, // 05 Keyboard b and B
   21, // 06 Keyboard c and C
   19, // 07 Keyboard d and D
   18, // 08 Keyboard e and E
   28, // 09 Keyboard f and F
   29, // 0A Keyboard g and G
   37, // 0B Keyboard h and H
   42, // 0C Keyboard i and I
   44, // 0D Keyboard j and J
   52, // 0E Keyboard k and K
   53, // 0F Keyboard l and L
   46, // 10 Keyboard m and M
   45, // 11 Keyboard n and N
   51, // 12 Keyboard o and O
   59, // 13 Keyboard p and P
    1, // 14 Keyboard q and Q
   27, // 15 Keyboard r and R
   13, // 16 Keyboard s and S
   26, // 17 Keyboard t and T
   43, // 18 Keyboard u and U
   30, // 19 Keyboard v and V
   10, // 1A Keyboard w and W
   20, // 1B Keyboard x and X
   36, // 1C Keyboard y and Y
   14, // 1D Keyboard z and Z
    3, // 1E Keyboard 1 and !
   11, // 1F Keyboard 2 and @
    9, // 20 Keyboard 3 and #
   17, // 21 Keyboard 4 and $
   25, // 22 Keyboard 5 and %
   35, // 23 Keyboard 6 and ∧
   34, // 24 Keyboard 7 and &
   41, // 25 Keyboard 8 and *
   50, // 26 Keyboard 9 and (
   58, // 27 Keyboard 0 and )
   76, // 28 Keyboard Return (ENTER)
    7, // 29 Keyboard ESCAPE
   77, // 2A Keyboard DELETE (Backspace)
    6, // 2B Keyboard Tab
   22, // 2C Keyboard Spacebar
   57, // 2D Keyboard - and (underscore)
   65, // 2E Keyboard = and +
   67, // 2F Keyboard [ and {
   69, // 30 Keyboard ] and }
   71, // 31 Keyboard \ and |
   60, // 32 Keyboard Non-US # and ˜
   61, // 33 Keyboard ; and :
   68, // 34 Keyboard ‘ and “
   66, // 35 Keyboard Grave Accent and Tilde
   54, // 36 Keyboard , and <
   62, // 37 Keyboard . and >
   70, // 38 Keyboard / and ?
    4, // 39 Keyboard Caps Lock
   15, // 3A Keyboard F1
   23, // 3B Keyboard F2
   31, // 3C Keyboard F3
   33, // 3D Keyboard F4
   39, // 3E Keyboard F5
   47, // 3F Keyboard F6
   49, // 40 Keyboard F7
   55, // 41 Keyboard F8
   63, // 42 Keyboard F9
    2, // 43 Keyboard F10
   -1, // 44 Keyboard F11
  127, // 45 Keyboard F12
   -1, // 46 Keyboard PrintScreen
    5, // 47 Keyboard Scroll Lock
  127, // 48 Keyboard Pause
   -1, // 49 Keyboard Insert
   -1, // 4A Keyboard Home
   -1, // 4B Keyboard PageUp
   -1, // 4C Keyboard Delete Forward
   78, // 4D Keyboard End
   -1, // 4E Keyboard PageDown
   79, // 4F Keyboard RightArrow
   73, // 50 Keyboard LeftArrow
   74, // 51 Keyboard DownArrow
   75, // 52 Keyboard UpArrow
   85, // 53 Keypad Num Lock and Clear
   84, // 54 Keypad /
   93, // 55 Keypad *
   91, // 56 Keypad -
   83, // 57 Keypad +
   99, // 58 Keypad ENTER
   94, // 59 Keypad 1 and End
  103, // 5A Keypad 2 and Down Arrow
  102, // 5B Keypad 3 and PageDn
   87, // 5C Keypad 4 and Left Arrow
   95, // 5D Keypad 5
   81, // 5E Keypad 6 and Right Arrow
   89, // 5F Keypad 7 and Home
   82, // 60 Keypad 8 and Up Arrow
   90, // 61 Keypad 9 and PageUp
   86, // 62 Keypad 0 and Insert
   92, // 63 Keypad . and Delete
   71, // 64 Keyboard Non-US \ and |
   -1, // 65 Keyboard Application
   -1, // 66 Keyboard Power
   -1, // 67 Keypad =
   -1, // 68 Keyboard F13
   -1, // 69 Keyboard F14
   -1, // 6A Keyboard F15
   -1, // 6B Keyboard F16
   -1, // 6C Keyboard F17
   -1, // 6D Keyboard F18
   -1, // 6E Keyboard F19
   -1, // 6F Keyboard F20
   -1, // 70 Keyboard F21
   -1, // 71 Keyboard F22
   -1, // 72 Keyboard F23
   -1, // 73 Keyboard F24
   -1, // 74 Keyboard Execute
   -1, // 75 Keyboard Help
   -1, // 76 Keyboard Menu
   -1, // 77 Keyboard Select
   -1, // 78 Keyboard Stop
   -1, // 79 Keyboard Again
   -1, // 7A Keyboard Undo
   -1, // 7B Keyboard Cut
   -1, // 7C Keyboard Copy
   -1, // 7D Keyboard Paste
   -1, // 7E Keyboard Find
   -1, // 7F Keyboard Mute
   -1, // 80 Keyboard Volume Up
   -1, // 81 Keyboard Volume Down
   -1, // 82 Keyboard Locking Caps Lock
   -1, // 83 Keyboard Locking Num Lock
   -1, // 84 Keyboard Locking Scroll Lock
   -1, // 85 Keypad Comma
   -1, // 86 Keypad Equal Sign
   -1, // 87 Keyboard International1
   -1, // 88 Keyboard International2
   -1, // 89 Keyboard International3
   -1, // 8A Keyboard International4
   -1, // 8B Keyboard International5
   -1, // 8C Keyboard International6
   -1, // 8D Keyboard International7
   -1, // 8E Keyboard International8
   -1, // 8F Keyboard International9
   -1, // 90 Keyboard LANG1
   -1, // 91 Keyboard LANG2
   -1, // 92 Keyboard LANG3
   -1, // 93 Keyboard LANG4
   -1, // 94 Keyboard LANG5
   -1, // 95 Keyboard LANG6
   -1, // 96 Keyboard LANG7
   -1, // 97 Keyboard LANG8
   -1, // 98 Keyboard LANG9
   -1, // 99 Keyboard Alternate Erase
   -1, // 9A Keyboard SysReq/Attention
   -1, // 9B Keyboard Cancel
   -1, // 9C Keyboard Clear
   -1, // 9D Keyboard Prior
   -1, // 9E Keyboard Return
   -1, // 9F Keyboard Separator
   -1, // A0 Keyboard Out
   -1, // A1 Keyboard Oper
   -1, // A2 Keyboard Clear/Again
   -1, // A3 Keyboard CrSel/Props
   -1, // A4 Keyboard Ex
   -1, // A5 Reserved
   -1, // A6 Reserved
   -1, // A7 Reserved
   -1, // A8 Reserved
   -1, // A9 Reserved
   -1, // AA Reserved
   -1, // AB Reserved
   -1, // AC Reserved
   -1, // AD Reserved
   -1, // AE Reserved
   -1, // AF Reserved
   -1, // B0 Keypad 00
   -1, // B1 Keypad 000
   -1, // B2 Thousands Separator
   -1, // B3 Decimal Separator
   -1, // B4 Currency Unit
   -1, // B5 Currency Sub-unit
   -1, // B6 Keypad (
   -1, // B7 Keypad )
   -1, // B8 Keypad {
   -1, // B9 Keypad }
   -1, // BA Keypad Tab
   -1, // BB Keypad Backspace
   -1, // BC Keypad A
   -1, // BD Keypad B
   -1, // BE Keypad C
   -1, // BF Keypad D
   -1, // C0 Keypad E
   -1, // C1 Keypad F
   -1, // C2 Keypad XOR
   -1, // C3 Keypad ∧
   -1, // C4 Keypad %
   -1, // C5 Keypad <
   -1, // C6 Keypad >
   -1, // C7 Keypad &
   -1, // C8 Keypad &&
   -1, // C9 Keypad |
   -1, // CA Keypad ||
   -1, // CB Keypad :
   -1, // CC Keypad #
   -1, // CD Keypad Space
   -1, // CE Keypad @
   -1, // CF Keypad !
   -1, // D0 Keypad Memory Store
   -1, // D1 Keypad Memory Recall
   -1, // D2 Keypad Memory Clear
   -1, // D3 Keypad Memory Add
   -1, // D4 Keypad Memory Subtract
   -1, // D5 Keypad Memory Multiply
   -1, // D6 Keypad Memory Divide
   -1, // D7 Keypad +/-
   -1, // D8 Keypad Clear
   -1, // D9 Keypad Clear Entry
   -1, // DA Keypad Binary
   -1, // DB Keypad Octal
   -1, // DC Keypad Decimal
   -1, // DD Keypad Hexadecimal
   -1, // DE Reserved
   -1, // DF Reserved
    8, // E0 Keyboard LeftControl
    0, // E1 Keyboard LeftShift
   -1, // E2 Keyboard LeftAlt
   -1, // E3 Keyboard Left GUI
    8, // E4 Keyboard RightControl
    0, // E5 Keyboard RightShift
   -1, // E6 Keyboard RightAlt
   -1, // E7 Keyboard Right
   -1, // E8 Reserved
   -1, // E9 Reserved
   -1, // EA Reserved
   -1, // EB Reserved
   -1, // EC Reserved
   -1, // ED Reserved
   -1, // EE Reserved
   -1, // EF Reserved
   -1, // F0 Reserved
   -1, // F1 Reserved
   -1, // F2 Reserved
   -1, // F3 Reserved
   -1, // F4 Reserved
   -1, // F5 Reserved
   -1, // F6 Reserved
   -1, // F7 Reserved
   -1, // F8 Reserved
   -1, // F9 Reserved
   -1, // FA Reserved
   -1, // FB Reserved
   -1, // FC Reserved
   -1, // FD Reserved
   -1, // FE Reserved
   -1  // FF Reserved
};

#define KEY_MOD_LCTRL  0x01
#define KEY_MOD_LSHIFT 0x02
#define KEY_MOD_LALT   0x04
#define KEY_MOD_LMETA  0x08
#define KEY_MOD_RCTRL  0x10
#define KEY_MOD_RSHIFT 0x20
#define KEY_MOD_RALT   0x40
#define KEY_MOD_RMETA  0x80

void processKeyboardInfo(u32 usbWord0, u32 usbWord1) {
	static u32 usbWord0_last = 0xFFFFFFFF;
	static u32 usbWord1_last = 0xFFFFFFFF;;
	if (usbWord0 != usbWord0_last || usbWord1 != usbWord1_last) {
		u32 bbcwords[4] = {0, 0, 0, 0};
		if (usbWord0 | usbWord1) {
			//printf("%08lx %08lx\n", usbWord0, usbWord1);
			if (usbWord0 & (KEY_MOD_LSHIFT | KEY_MOD_RSHIFT)) {
				bbcwords[0] |= 0x1;
			}
			if (usbWord0 & (KEY_MOD_LCTRL | KEY_MOD_RCTRL)) {
				bbcwords[0] |= 0x100;
			}
			for (int key = 0; key < 6; key++) {
				uint8_t current = (
						(key < 4) ?
								(usbWord1 >> (key * 8)) :
								(usbWord0 >> (key * 8 - 16))) & 0xff;
				int8_t scancode = bbc_map[current];
				if (scancode >= 0) {
					u32 *bbcword = bbcwords + (scancode >> 5);
					*bbcword |= 1 << (scancode & 0x1F);
				}
			}
		}
		Xil_Out32(GPIO_REG0, bbcwords[0]);
		Xil_Out32(GPIO_REG1, bbcwords[1]);
		Xil_Out32(GPIO_REG2, bbcwords[2]);
		Xil_Out32(GPIO_REG3, bbcwords[3]);
		usbWord0_last = usbWord0;
		usbWord1_last = usbWord1;
	}
}

qtd_type *calNextPointer(qtd_type * currentpointer) {
	currentpointer++;
	if (currentpointer >= USB_ASYNC_QTD + NUM_QTD) {
		currentpointer = USB_ASYNC_QTD;
	}
	return currentpointer;
}

void set_port_reset_state(int do_reset) {
	u32 in2;
	if (do_reset) {
		in2 = Xil_In32(USB0_PORTSCR1) | 256;
		Xil_Out32(USB0_PORTSCR1, in2);
	} else {
		in2 = Xil_In32(USB0_PORTSCR1) & (~256);
		Xil_Out32(USB0_PORTSCR1, in2);
	}

}

void schedTransfer(int setup, int direction, int size, qh_type *qh) {
	qtd_type *first_qtd = qh->qtd.next;
	qtd_type *firstTD = first_qtd;
	qtd_type *nextTD = first_qtd;
	if (setup) {
		firstTD->next = calNextPointer(first_qtd); //next qtd + terminate
		firstTD->altnext = QTD_TERMINATOR; // alternate pointer
		firstTD->token = 0x00080240; //with setup keep haleted/non active till everything setup
		firstTD->buffer = USB_ASYNC_DATA0; //buffer for setup command

	}
	if (size > 0) {
		if (setup) {
			nextTD = calNextPointer(first_qtd);
		}

		nextTD->next = calNextPointer(nextTD); //next qtd + terminate
		nextTD->altnext = QTD_TERMINATOR; // alternate pointer
		nextTD->token = (size << 16) | (direction << 8)	| (nextTD == firstTD ? 0x40 : 0x80) | 0x80000000;
		if (direction == 0) {
			nextTD->token |= 0x8000;
		}
		nextTD->buffer = setup ? USB_ASYNC_DATA1 : USB_ASYNC_DATA0; //buffer for setup command

		nextTD = calNextPointer(nextTD);

		if (direction == 1) {
			nextTD->next = calNextPointer(nextTD); //next qtd + terminate
			nextTD->altnext = QTD_TERMINATOR; // alternate pointer
			nextTD->token = 0x80008080; //with setup keep haleted/non active till everything setup
			nextTD->buffer = USB_ASYNC_DATA0; //buffer for setup command
		}
	} else {
		//size = 0
		nextTD = calNextPointer(first_qtd);
		nextTD->next = calNextPointer(nextTD); //next qtd + terminate
		nextTD->altnext = QTD_TERMINATOR; // alternate pointer
		nextTD->token = (0 << 16) | (1 << 8) | (nextTD == firstTD ? 0x40 : 0x80) | 0x80008000;

	}
	if (nextTD == firstTD) {
		nextTD->token |= 0x8000;
	}
	nextTD = calNextPointer(nextTD);
	nextTD->next = QTD_TERMINATOR; //next qtd + terminate
	nextTD->altnext = QTD_TERMINATOR; // alternate pointer
	nextTD->token = 0x40; //with setup keep haleted/non active till everything setup
	nextTD->buffer = USB_ASYNC_DATA0; //buffer for setup command
	firstTD->token = (firstTD->token & (~0x40)) | 0x80;
}

void initUsb() {
	Xil_Out32(USB0_MODE, 3); //set to host mode
	u32 in2 = Xil_In32(USB0_PORTSCR1) | 4096;
	Xil_Out32(USB0_PORTSCR1, in2); //switch port power on


	/* ULPI set flags */
	ulpi_write(&ulpi_vp, &ulpi->otg_ctrl,
		   ULPI_OTG_DP_PULLDOWN | ULPI_OTG_DM_PULLDOWN |
		   ULPI_OTG_EXTVBUSIND);
	ulpi_write(&ulpi_vp, &ulpi->function_ctrl,
		   ULPI_FC_FULL_SPEED | ULPI_FC_OPMODE_NORMAL |
		   ULPI_FC_SUSPENDM);
	ulpi_write(&ulpi_vp, &ulpi->iface_ctrl, 0);

	/* Set VBus */
	ulpi_write(&ulpi_vp, &ulpi->otg_ctrl_set,
		   ULPI_OTG_DRVVBUS | ULPI_OTG_DRVVBUS_EXT);

	usleep(1000000);

	memset(USB_ASYNC_QH, 0, 1000000);

	qh_type *qh;
	qh = USB_ASYNC_QH;
	qh->qh_link = QH_LINK(USB_ASYNC_QH);
	qh->qh_endpt1 = 0xf808d000; //enable H bit -> head of reclamation
	qh->qh_endpt2 = 0x40000000;
	qh->current_qtd = 0;
	qh->qtd.next = USB_ASYNC_QTD; // pointer to halt qtd
	qh->qtd.altnext = QTD_TERMINATOR; // no alternate

	qtd_type *qTD;
	qTD = USB_ASYNC_QTD;
	qTD->next = QTD_TERMINATOR; //next qtd + terminate
	qTD->altnext = 0; // alternate pointer
	qTD->token = 0x40; //halt value// setup packet 80 to activate

	Xil_Out32(USB0_ASYNCLISTADDR, (u32) USB_ASYNC_QH); // set async base
	in2 = Xil_In32(USB0_CMD) | 0x1;
	Xil_Out32(USB0_CMD, in2); //enable rs bit

	in2 = Xil_In32(USB0_CMD) | 0x20;
	Xil_Out32(USB0_CMD, in2); // enable async processing

}

void initint() {
	myhelp = 1;
	IntcConfig = XScuGic_LookupConfig(0);
	XScuGic_CfgInitialize(&INTCInst, IntcConfig, IntcConfig->CpuBaseAddress);
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler) XScuGic_InterruptHandler, &INTCInst);
	Xil_ExceptionEnable();
	XScuGic_Connect(&INTCInst, 53, (Xil_ExceptionHandler) state_machine, (void *) myhelp);
	XScuGic_Enable(&INTCInst, 53);
	u32 in2 = Xil_In32(USB0_IER) | (1 << 24) | (1 << 18);
	Xil_Out32(USB0_IER, in2); //enable
}

void setup_periodic() {
	qh_type *qh;
	u32 in2 = Xil_In32(USB0_CMD) | (1 << 15) | 8;
	Xil_Out32(USB0_CMD, in2);

	for (int i = 0; i < 16; i++) {
		USB_LISTBASE[i] = QH_TERMINATOR;
	}

	Xil_Out32(USB0_LISTBASE, (u32) USB_LISTBASE);

	qh = USB_PERIODIC_QH;
	qh->qh_link = QH_LINK(USB_PERIODIC_QH1);
	qh->qh_endpt1 = 0;
	qh->qh_endpt2 = 0;
	qh->current_qtd = 0;
	qh->qtd.next = QTD_TERMINATOR;
	qh->qtd.altnext = QTD_TERMINATOR;

	qh = USB_PERIODIC_QH1;
	qh->qh_link = QH_LINK(QH_TERMINATOR);
	qh->qh_endpt1 = 0x00085103;
	qh->qh_endpt2 = 0x40000001;
	qh->current_qtd = 0;
	qh->qtd.next = USB_PERIODIC_QTD1;
	qh->qtd.altnext = QTD_TERMINATOR;

	qtd_type *qTD = USB_PERIODIC_QTD1;
	qTD->next = QTD_TERMINATOR;
	qTD->altnext = QTD_TERMINATOR;
	qTD->token = 0x00080180;
	qTD->buffer = USB_PERIODIC_DATA;

	//set first frame to qh
	USB_LISTBASE[0] = QH_LINK(USB_PERIODIC_QH);
}

void state_machine() {
	u32 in2 = Xil_In32(USB0_ISR) | (1 << 24) | (1 << 18);
	Xil_Out32(USB0_ISR, in2); //clear

	if (status == ST_INITIAL) {
		set_port_reset_state(1);
		scheduleTimer(12000);
		status = ST_RESET;
		return;
	} else if (status == ST_RESET) {
		set_port_reset_state(0);
		scheduleTimer(12000);
		status = ST_SET_ADDRESS;
		return;
	} else if (status == ST_SET_ADDRESS) {
		//set address
		USB_ASYNC_DATA0[0] = 0x00030500;
		USB_ASYNC_DATA0[1] = 0x00000000;
		schedTransfer(1, 0, 0, USB_ASYNC_QH);
		status = ST_DELAY;
		return;
	} else if (status == ST_DELAY) {
		scheduleTimer(3000);
		status = ST_SET_CONFIGURATION;
		return;
	} else if (status == ST_SET_CONFIGURATION) {
		USB_ASYNC_QH->qh_endpt1 |= 3;
		//set configuration
		USB_ASYNC_DATA0[0] = 0x00010900;
		USB_ASYNC_DATA0[1] = 0x00000000;
		schedTransfer(1, 0, 0, USB_ASYNC_QH);
		status = ST_SETUP_PERIODIC;
		return;
	} else if (status == ST_SETUP_PERIODIC) {
		//enable periodic scheduling
		setup_periodic();
		in2 = Xil_In32(USB0_CMD) | 16;
		Xil_Out32(USB0_CMD, in2);
		status = ST_PERIODIC;
		scheduleTimer(10000);
		return;
	} else if (status == ST_PERIODIC) {
		qtd_type *qTDAddress = currentTD ? USB_PERIODIC_QTD1 : USB_PERIODIC_QTD2;
		qtd_type *qTDAddressCheck = currentTD ? USB_PERIODIC_QTD2 : USB_PERIODIC_QTD1;

		u32 toggle = qTDAddressCheck->token & 0x80000000;
		if (!(qTDAddressCheck->token & 0x80)) {
			u32 word0 = USB_PERIODIC_DATA[0];
			u32 word1 = USB_PERIODIC_DATA[1];
            processKeyboardInfo(word0, word1);

			qh_type *qh = USB_PERIODIC_QH;
			qh->qh_link = QH_LINK(QH_TERMINATOR);

			qh_type *qh2 = currentTD ? USB_PERIODIC_QH1 : USB_PERIODIC_QH2;
			qh2->qh_link = QH_LINK(QH_TERMINATOR);
			qh2->qh_endpt1 = 0x00085103;
			qh2->qh_endpt2 = 0x40000001;
			qh2->current_qtd = 0;
			qh2->qtd.next = qTDAddress;
			qh2->qtd.altnext = QTD_TERMINATOR;

			qtd_type *qTD = qTDAddress;
			qTD->next = QTD_TERMINATOR;
			qTD->altnext = QTD_TERMINATOR;
			qTD->token = 0x00080180 | toggle; //halt value// setup packet 80 to activate
			qTD->buffer = USB_PERIODIC_DATA;

			qh->qh_link = QH_LINK(qh2);
			currentTD = ~currentTD;
		}
		scheduleTimer(10000);
		return;
	}

}

int main() {
	int ret;
	u8 buffer[UART_BUFFER_SIZE];
	int len;
	int led;

	XUartPs_Config *Config_0;
	XUartPs Uart_PS_0;
	XUartPs_Config *Config_1;
	XUartPs Uart_PS_1;

	// TODO: It would be nice to do the cache management properly!
	Xil_DCacheDisable();

	init_platform();

	/*************************
	 * UART 0 initialization *
	 *************************/

	Config_0 = XUartPs_LookupConfig(XPAR_XUARTPS_0_DEVICE_ID);
	if (NULL == Config_0) {
		return XST_FAILURE;
	}
	ret = XUartPs_CfgInitialize(&Uart_PS_0, Config_0, Config_0->BaseAddress);
	if (ret != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*************************
	 * UART 1 initialization *
	 *************************/

	Config_1 = XUartPs_LookupConfig(XPAR_XUARTPS_1_DEVICE_ID);
	if (NULL == Config_1) {
		return XST_FAILURE;
	}
	ret = XUartPs_CfgInitialize(&Uart_PS_1, Config_1, Config_1->BaseAddress);
	if (ret != XST_SUCCESS) {
		return XST_FAILURE;
	}
	printf("BeebFPGA USB/UART App booted!!!\r\n\r\n");

	/*************************
	 * USB/KB initialization *
	 *************************/

	// Clear the emulated keyboard matrix registers
	Xil_Out32(GPIO_REG0, 0);
	Xil_Out32(GPIO_REG1, 0);
	Xil_Out32(GPIO_REG2, 0);
	Xil_Out32(GPIO_REG3, 0);

	initint();
	initUsb();
	status = ST_INITIAL;
	state_machine();

	//	dump_ulpi();
	//
	//	for (u32 i = USB_ASYNC_QH; i < USB_ASYNC_QH + 0x100; i += 4) {
	//		printf("%x = %x\n", i, *((u32 *)i));
	//	}
	//	for (u32 i = USB_ASYNC_DATA0; i < USB_ASYNC_DATA0 + 0x1C; i += 4) {
	//		printf("%x = %x\n", i, *((u32 *)i));
	//	}
	//	for (u32 i = USB_ASYNC_DATA1; i < USB_ASYNC_DATA1 + 0x1C; i += 4) {
	//		printf("%x = %x\n", i, *((u32 *)i));
	//	}
	//
	//	printf("USB0_ISR = %x\n", *((u32 *)USB0_ISR));
	//	printf("USB0_ASYNCLISTADDR = %x\n", *((u32 *)USB0_ASYNCLISTADDR));

	/*******************************
	 * Cross Connect the two UARTs *
	 *******************************/

	while (1) {
		len = XUartPs_Recv(&Uart_PS_0, buffer, sizeof(buffer));
		if (len > 0) {
			XUartPs_Send(&Uart_PS_1, buffer, len);
		}
		len = XUartPs_Recv(&Uart_PS_1, buffer, sizeof(buffer));
		if (len > 0) {
			XUartPs_Send(&Uart_PS_0, buffer, len);
			led = !led;
		}
	}
	cleanup_platform();
	return 0;
}
