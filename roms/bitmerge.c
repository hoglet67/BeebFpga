/************************************************************************
* bitmerge.cpp : Merges a binary file into an Xilinx bistream
* Author       : Mike Field <hamster@snap.net.nz>
* Usage        : bitmerge bitstream.bit  2F00:data.bin merged.bit
*
* Adds the contents of "data.bin" into the bitsteam at address 2F00
*
* It is up to you to make sure that the resulting bitstream will 
* fit inside you FPGA's configuration flash!
*
* Inspired by Alex's bitmerge.py on http://Papilio.cc
*
* Please feel free to use however you please, but it is supplied "as is, 
* where is"
*
************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>

static unsigned char header[] = { 0, 9 , 0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0, 0x0F, 0xF0, 0};

unsigned char *buffer;
int inlen,binlen;

static int error(char *message) {
   fprintf(stderr, "ERROR: %s\n", message);
   exit(2);
}


static void checkTextSection(char tag, int *inptr)
{
   unsigned len;
   if(*inptr > inlen-3) error("Section too short");
   if(buffer[*inptr] != tag) error("Unexpected section tag");
   len = (buffer[*inptr+1]<<8)+buffer[*inptr+2];
   // printf("Section '%c' (size %6d) '%*.*s'\n", buffer[*inptr], len, len-1, len-1, buffer+*inptr+3);
   *inptr += len+3;
}

int main(int argc, char *argv[])
{
   FILE *f;
   int inptr = 0, align = 0, padding, bitstreamLen, bitstreamAddr;

   if(argc != 4) {
      fprintf(stderr,"Usage: %s input.bit hex_address:binary_file output.bit\n\n"
             "Concatenates a binary file into an Xilinx FPGA bitstream\n",argv[0]);
      return 1;
   }

   while(1) {
      char c = argv[2][0];
      argv[2]++;
      if(c >= '0' && c <= '9')      align = align * 16 + c - '0';
      else if(c >= 'A' && c <= 'F') align = align * 16 + c - 'A'+10;
      else if(c >= 'a' && c <= 'f') align = align * 16 + c - 'a'+10;      
      else if(c == ':') break;
      else error("Expected a hex address followed by a colon before binary file name");
   }

   if(NULL == (f = fopen(argv[1],"rb"))) error("Unable to open input .bit file");
   /* Work out the length of the files */
   fseek(f,0,SEEK_END);
   if((inlen = ftell(f)) == 0) error("Input file is too short");
   fseek(f,0,SEEK_SET);

   /* Read in the input file */
   if((buffer = (unsigned char *)malloc(inlen)) == NULL) error("Out of memory");
   if(fread(buffer, inlen, 1, f) != 1)               error("Unable to read input file");
   fclose(f);

   /* Check that the expected magic numbers are in the header */
   if(memcmp(buffer,header, sizeof(header))!=0)    error("Invalid .bit file header");
   inptr = sizeof(header);

   if((buffer[inptr]<<8)+buffer[inptr+1] != 1) error("expecting a '1'");
   inptr+=2;

   checkTextSection('a',&inptr);
   checkTextSection('b',&inptr);
   checkTextSection('c',&inptr);
   checkTextSection('d',&inptr);

   if(inptr >= inlen - 5)
   if(buffer[inptr] != 'e') error("Expected section 'e', got something else");

   bitstreamAddr = inptr+5;
   bitstreamLen = (buffer[inptr+1]<<24) + (buffer[inptr+2]<<16) + (buffer[inptr+3]<<8) + (buffer[inptr+4]);
   printf("\nFPGA Bitstream is %i bytes (%i bits)\n", bitstreamLen, bitstreamLen*8);
   inptr+=5;

   if(bitstreamAddr + bitstreamLen != inlen)  error("File length differs from the expected");

   /* Pad the bitstream out with zeros to the address */
   padding = align-bitstreamLen;
   if(padding < 0)   error("Data location will overwrite FPGA bitstream");
   if(padding > 0) {
      printf("Padding bitstream with %i zero bytes\n", padding);
      if((buffer = (unsigned char *)realloc(buffer,inlen+padding)) == NULL) error("Out of memory");
      memset(buffer+inlen,0,padding);
      inlen += padding;
      bitstreamLen += padding;
   }

   /* Append the binary data to the padded bitstream */
   if(NULL == (f = fopen(argv[2],"rb"))) error("Unable to open data .bit file");
   fseek(f,0,SEEK_END);
   if((binlen = ftell(f))== 0) error("Binary file is too short");
   fseek(f,0,SEEK_SET);
   printf("Appending %i bytes of data to the bitstream at address %x\n",binlen, align);

   if((buffer = (unsigned char *)realloc(buffer,inlen+binlen)) == NULL) error("Out of memory");
   if(fread(buffer+inlen, binlen, 1, f) != 1) error("Unable to read binary file");
   fclose(f);
   inlen += binlen;
   bitstreamLen += binlen;

   /* backpatch the length of the updated bitstream */
   buffer[bitstreamAddr-4] = (unsigned char)(bitstreamLen>>24);
   buffer[bitstreamAddr-3] = (unsigned char)(bitstreamLen>>16);
   buffer[bitstreamAddr-2] = (unsigned char)(bitstreamLen>>8);
   buffer[bitstreamAddr-1] = (unsigned char)(bitstreamLen>>0);

   if((f = fopen(argv[3],"wb")) == NULL) error("Unable to open output file");
   if(fwrite(buffer,inlen,1,f) != 1) error("Unable to write file\n");
   fclose(f);
   printf("Written new file with a bitstream of %i bytes (%i bits)\n", bitstreamLen, bitstreamLen*8);
   return 0;
}
