/*****************************************
 * hdmi_decode.c
 *
 * AUthor:  Mike Field <hamster@snap.net.nz<
 *
 * A Little utility to convert hex strings
 * into HDMI CTL and TERC4 symbols for
 * further analysis.
 ***************************************/
#include <stdio.h>

void ctl_decode(unsigned s) {
  switch(s) {
     case 0x354: printf(" CTL0"); return;
     case 0x0AB: printf(" CTL1"); return;
     case 0x154: printf(" CTL2"); return;
     case 0x2AB: printf(" CTL3"); return;
  }
  printf("     ");
}

int terc4_decode(unsigned s) {
   int ret = -1;
   switch(s) {
   case 0x29C: ret=0x0; break;
   case 0x263: ret=0x1; break;
   case 0x2E4: ret=0x2; break;
   case 0x2E2: ret=0x3; break;

   case 0x171: ret=0x4; break;
   case 0x11E: ret=0x5; break;
   case 0x18E: ret=0x6; break;
   case 0x13C: ret=0x7; break;

   case 0x2CC: ret=0x8; break;
   case 0x139: ret=0x9; break;
   case 0x19C: ret=0xA; break;
   case 0x2C6: ret=0xB; break;

   case 0x28E: ret=0xC; break;
   case 0x271: ret=0xD; break;
   case 0x163: ret=0xE; break;
   case 0x2C3: ret=0xF; break;
   }
   if (ret >= 0) {
      printf(" %x", ret);
   } else {
      printf("  ");
   }
   return ret;
}

int byteswap(int i) {
   return
      ((i & 0x01) << 7) |
      ((i & 0x02) << 5) |
      ((i & 0x04) << 3) |
      ((i & 0x08) << 1) |
      ((i & 0x10) >> 1) |
      ((i & 0x20) >> 3) |
      ((i & 0x40) >> 5) |
      ((i & 0x80) >> 7);
}


int main(int argc, char *argv[])
{
  FILE *f;
  unsigned value;
  unsigned n = 0;
  int data_state = 0;
  int data_active = 0;

  unsigned int hdr;
  unsigned char payload[32];
  unsigned last_ch0 = 0;
  unsigned last_ch1 = 0;
  unsigned last_ch2 = 0;

  f = fopen(argv[1], "rb");
  if(f == NULL) {
     fprintf(stderr,"Unable to open file\n");
     return 1;
  }

  while(fscanf(f,"%x",&value) == 1)
  {
    unsigned ch2, ch1, ch0;
    int terc2, terc1, terc0;
    ch2 = (value>>20)&0x3FF;
    ch1 = (value>>10)&0x3FF;
    ch0 = (value>> 0)&0x3FF;
    printf("%8i: %03X %03X %03X   ",n, ch2, ch1, ch0);
    ctl_decode(ch2);
    ctl_decode(ch1);
    ctl_decode(ch0);
    terc2 = terc4_decode(ch2);
    terc1 = terc4_decode(ch1);
    terc0 = terc4_decode(ch0);
    printf("\n");

    if (last_ch1 = 0x133 && ch1 == 0x133 && last_ch2 == 0x133 && ch2 == 0x133) {
       data_active = !data_active;
       if (data_active) {
          data_state = 0;
       }
    } else if (data_active) {
       hdr = (hdr << 1) | ((terc0 >> 2) & 1);
       payload[data_state] = 0;
       data_state = (data_state + 1) & 31;
       if (!data_state) {
          printf("%8i Header", n);
          printf(" %02x", byteswap(hdr >> 24));
          printf(" %02x", byteswap(hdr >> 16));
          printf(" %02x", byteswap(hdr >>  9));
          printf(" %02x", byteswap(hdr      ));
          printf("\n");
#if 0
          printf("Payload:");
          for (int = 0; i < 32; i++) {
             printf(" %02x", payload[i]);
          }
          printf("\n");
#endif
       }
    }

    last_ch2 = ch2;
    last_ch1 = ch1;
    last_ch0 = ch0;
    n++;
  }
  fclose(f);
  return 0;
}
