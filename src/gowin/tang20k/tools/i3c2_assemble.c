/****************************************************************
 * i3c2_assemble.c : Compiler for my i2c scripting language
 *
 * Author : Mike Field <hamster@snap.net.nz>
 *
 ***************************************************************/
//#include "stdafx.h"  // For MS-Visual C++

#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <malloc.h>
#include <memory.h>

#define BUFFER_SIZE 128
#define MEM_SIZE    1024

/*
  -- |Opcode   | Instruction | Action
  -- +---------+-------------+----------------------------------------
  -- |00nnnnnnn| JUMP m      | Set PC to m (n = m/8)
  -- |01000nnnn| SKIPCLEAR n | Skip if input n clear
  -- |01001nnnn| SKIPSET n   | skip if input n set
  -- |01010nnnn| CLEAR n     | Clear output n
  -- |01011nnnn| SET n       | Set output n
  -- |0110nnnnn| READ n      | Read to register n
  -- |01110nnnn| DELAY m     | Delay m clock cycles (n = log2(m))
  -- |011110000| SKIPNACK    | Skip if NACK is set
  -- |011110001| SKIPACK     | Skip if ACK is set
  -- |011110010| WRITELOW    | Write inputs 7 downto 0 to the I2C bus
  -- |011110011| WRITEHI     | Write inputs 15 downto 8 to the I2C bus
  -- |011110100| USER0       | User defined
  -- |.........|             |
  -- |011111100| USER8       | User defined
  -- |011111101| MASTERACK   | ACK on next READ (default is NACK)
  -- |011111110| NOP         | Do nothing
  -- |011111111| STOP        | Send Stop on i2C bus
  -- |1nnnnnnnn| WRITE n     | Output n on I2C bus
*/
struct Opcode {
   char *text;
   int has_value;
   int max_value;
   int has_label;
   int has_delay;
   int base_opcode;
} opcodes[] = {
   {"JUMP",      0,  0,1, 0, 0x000},
   {"SKIPCLEAR", 1, 15,0, 0, 0x080},
   {"SKIPSET",   1, 15,0, 0, 0x090},
   {"CLEAR",     1, 15,0, 0, 0x0A0},
   {"SET",       1, 15,0, 0, 0x0B0},
   {"READ",      1, 31,0, 0, 0x0C0},
   {"DELAY",     1, 15,0, 1, 0x0E0},
   {"SKIPNACK",  0,  0,0, 0, 0x0F0},
   {"SKIPACK",   0,  0,0, 0, 0x0F1},
   {"WRITELOW",  0,  0,0, 0, 0x0F2},
   {"WRITEHI",   0,  0,0, 0, 0x0F3},
   {"MASTERACK", 0,  0,0, 0, 0x0FD},
   {"NOP",       0,  0,0, 0, 0x0FE},
   {"STOP",      0,  0,0, 0, 0x0FF},
   {"WRITE",     1,255,0, 0, 0x100}

};
#define OPCODES_LEN ((int)(sizeof(opcodes)/sizeof(struct Opcode)))

#define OPCODE_NOP 0x0FE

unsigned memory[MEM_SIZE];
unsigned memory_used = 0;

struct Backpatch {
   struct Backpatch *next;
   int address;
};

struct Symbol {
   struct Symbol *next;
   char *name;
   int firstLine;
   int value;
   struct Backpatch *backpatch;
   char resolved;
} *firstSymbol;


int printbits(FILE *f, int value, int len)
{
   int mask = 1;
   int j;
   for(j = 1; j < len; j++)
      {
         mask += mask;
      }
   while(mask > 0)
      {
         putc((value & mask) ? '1' : '0',f);
         mask /= 2;
      }
   return 1;
}

int output_object_code_coe(FILE *f)
{
   int i;
   fprintf(f,"memory_initialization_radix = 2;\n");
   fprintf(f,"memory_initialization_vector = \n");

   for(i = 0; i < memory_used; i++)
      {
         fprintf(f,"   ");
         printbits(f,memory[i],9);
         fprintf(f,"\n");
      }
   fprintf(f,";\n");
   return 1;
}

int output_object_code_vhdl(FILE *f,char *name)
{
   int i;
   fprintf(f,"library IEEE;\n");
   fprintf(f,"use IEEE.STD_LOGIC_1164.ALL;\n");
   fprintf(f,"use IEEE.NUMERIC_STD.ALL;\n");
   fprintf(f,"\n");
   fprintf(f,"entity %s is\n",name);
   fprintf(f,"   Port ( clk     : in    STD_LOGIC;\n");
   fprintf(f,"          data    : out std_logic_vector(8 downto 0);\n");
   fprintf(f,"          address : in std_logic_vector(9 downto 0)\n");
   fprintf(f,"         );\n");
   fprintf(f,"end %s;",name);
   fprintf(f,"\n");
   fprintf(f,"architecture Behavioral of %s is\n", name);
   fprintf(f,"begin\n");
   fprintf(f,"   process(clk)\n");
   fprintf(f,"   begin\n");
   fprintf(f,"      if rising_edge(clk) then\n");
   fprintf(f,"         case address is\n");

   for(i = 0; i < memory_used; i++)
      {
         fprintf(f,"           when \"");
         printbits(f,i,10);
         fprintf(f,"\" => data <= \"");
         printbits(f,memory[i],9);
         fprintf(f,"\";\n");
      }
   fprintf(f,"           when others => data <= (others =>'0');\n");
   fprintf(f,"        end case;\n");
   fprintf(f,"     end if;\n");
   fprintf(f,"   end process;\n");
   fprintf(f,"end Behavioral;\n");
   return 1;
}

void printSymbols(void)
{
   struct Symbol *s = firstSymbol;
   fprintf(stderr, "\nSymbols:\n-------\n");
   while(s != NULL)
      {
         fprintf(stderr, "  %4i %s\n", s->value, s->name);
         s = s->next;
      }
}

int labelStart(int c) {
   return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

int labelChar(int c) {
   return labelStart(c) || (c >= '0' && c <= '9');
}

int whitespace(int c) {
   return c == ' ' || c == '\t';
}

struct Symbol *symbolSearch(char *name, int len)
{
   struct Symbol *s = firstSymbol;
   while(s != NULL)
      {
         if(strncmp(s->name,name,len)==0)
            break;
         s = s->next;
      }
   return s;
}

int symbolAddBackpatch(struct Symbol *s, int address)
{
   struct Backpatch *b = (struct Backpatch *)malloc(sizeof(struct Backpatch));
   if(b == NULL)
      {
         fprintf(stderr,"Out of memory\n");
         return 0;
      }
   memset(b,0,sizeof(struct Backpatch));
   b->address = address;
   b->next = s->backpatch;
   s->backpatch = b;
   return 1;
}

/*********************************************************************/
int getOperand(char *text, int *val, int line)
{
   while(whitespace(*text))
      text++;

   if(*text == '0' && text[1] == 'x')
      {
         text+=2;
         if(*text >= '0' && *text <= '9')
            *val = *text - '0';
         else if(*text >= 'a' && *text <= 'f')
            *val = *text - 'a' + 10;
         else if(*text >= 'A' && *text <= 'F')
            *val = *text - 'A' + 10;
         else {
            fprintf(stderr, "Invalid hex number on line %i\n", line);
            return 0;
         }
         text++;
         if(*text >= '0' && *text <= '9') {
            *val = *val * 16 + *text - '0';
            text++;
         } else if(*text >= 'a' && *text <= 'f') {
            *val = *val * 16 + *text - 'a' + 10;
            text++;
         } else if(*text >= 'A' && *text <= 'F') {
            *val = *val * 16 + *text - 'A' + 10;
            text++;
         }
      } else if(*text >= '0' && *text <= '9') {
      *val = *text - '0';
      text++;
      while(*text >= '0' && *text <= '9') {
         *val = *val * 10 + *text - '0';
         text++;
      }
   } else if(*text == '0') {
      *val = 0;
      text++;
   }

   while(whitespace(*text))
      text++;
   if(*text == '\0')
      return 1;
   if(*text == ';')
      return 1;

   fprintf(stderr, "Invalid character on line %i\n", line);
   return 0;
}

/*********************************************************************/
struct Symbol *symbolNew(char *name, int len, int line)
{
   struct Symbol *s;
   /* Make new symbol */
   s = (struct Symbol *)malloc(sizeof(struct Symbol));

   if(s == NULL)
      {
         fprintf(stderr,"Out of memory\n");
         return NULL;
      }
   memset(s,0,sizeof(struct Symbol));

   s->name = (char *)malloc(len+1);
   if(s->name == NULL)
      {
         fprintf(stderr,"Out of memory\n");
         free(s);
         return 0;
      }
   memcpy(s->name, name, len);
   s->name[len] = '\0';
   s->firstLine = line;

   /* Add the symbol into the list */
   s->next = firstSymbol;
   firstSymbol = s;
   return s;
}

int parse_line(int line, char *buffer)
{
   int i = 0, o=0, value = 0;
   struct Symbol *symbol = NULL;

   if(buffer[i] == '\0')     /* Empty line? */
      return 1;

   /*************************************************************************
    * First field is the label. If one is there we find the symbol or create
    * a new one and assign the current memory address
    *************************************************************************/

   if(labelStart(buffer[i])) /* Is there the start of a label on the line? */
      {
         struct Symbol *s = firstSymbol;

         /* Pull the label off the line */
         while(labelChar(buffer[i]))
            i++;
         if(buffer[i] != ':')
            {
               fprintf(stderr, "Invalid Label on line %i\n", line);
               return 0;
            }

         /* See if we can find the symbol */
         s = symbolSearch(buffer,i);

         if( s == NULL)
            {
               s = symbolNew(buffer,i,line);
            }
         i++; /* Skip over the ':' */
         if(s->resolved) {
            fprintf(stderr,"Label already defined '%s'\n",s->name);
            return 0;
         }

         /* Pad memory with NOPs till aligned with the 8 word boundary */
         while((memory_used & 0x7) != 0)
            {
               memory[memory_used] = OPCODE_NOP;
               memory_used++;
            }
         s->value = memory_used;
         s->resolved = 1;

         /* Finalise any opcodes that need to have this address */
         if(s->backpatch != NULL)
            {
               struct Backpatch *b = s->backpatch;
               /* Make sure that the instruction to be updated is a JUMP to address 0 */
               assert(memory[b->address] == 0);
               memory[b->address] = memory_used/8;
               s->backpatch = b->next;
               free(b);
            }

      }
   else if(buffer[i] == ';') /* Is it all a comment? */
      return 1;
   else if(!whitespace(buffer[i]))
      {
         fprintf(stderr, "Invalid Label on line %i\n", line);
         return 0;
      }

   while(whitespace(buffer[i])) {
      i++;
   }

   if(buffer[i] == ';') /* Does it have a comment? */
      return 1;

   if(buffer[i] == '\0') /* End of line? */
      return 1;

   for(o = 0; o < OPCODES_LEN; o++)
      {
         if(strncmp(buffer+i,opcodes[o].text,strlen(opcodes[o].text)) == 0)
            break;
      }
   if(o == OPCODES_LEN) {
      fprintf(stderr,"Error: Unknown opcode on line %i\n",line);
      return 0;
   }

   i += strlen(opcodes[o].text);

   /* if opcode has no opperands */
   if(!opcodes[o].has_label && !opcodes[o].has_value && !opcodes[o].has_delay)
      {
         if(!(buffer[i] == ';') && !(buffer[i] == '\0')) {
            if(!whitespace(buffer[i])) {
               fprintf(stderr,"Error: Unknown opcode on line %i\n",line);
               return 0;
            }

            while(whitespace(buffer[i]))
               i++;
         }
      }
   else if(!whitespace(buffer[i]))
      {
         fprintf(stderr,"Error: Operand expected on line %i\n",line);
         return 0;
      }

   while(whitespace(buffer[i]))
      i++;

   if(opcodes[o].has_label)
      {
         int len = 0;

         if(!labelStart(buffer[i]))
            {
               fprintf(stderr,"Error: Expeced label on  line %i\n",line);
               return 0;
            }


         while(labelChar(buffer[i+len]))
            len++;
         symbol = symbolSearch(buffer+i,len);
         if(symbol == NULL) {
            symbol = symbolNew(buffer+i,len,line);
            symbolAddBackpatch(symbol,memory_used);
         }
         i += len;
         value = symbol->value;
      }

   if(opcodes[o].has_delay)
      {
         if     (strncmp(buffer+i,"32768",5) == 0){ value = 15; i+=5; }
         else if(strncmp(buffer+i,"16384",5) == 0){ value = 14; i+=5; }
         else if(strncmp(buffer+i,"8192",4)  == 0){ value = 13; i+=4; }
         else if(strncmp(buffer+i,"4096",4)  == 0){ value = 12; i+=4; }
         else if(strncmp(buffer+i,"2048",4)  == 0){ value = 11; i+=4; }
         else if(strncmp(buffer+i,"1024",4)  == 0){ value = 10; i+=4; }
         else if(strncmp(buffer+i,"512",3)   == 0){ value =  9; i+=3; }
         else if(strncmp(buffer+i,"256",3)   == 0){ value =  8; i+=3; }
         else if(strncmp(buffer+i,"128",3)   == 0){ value =  7; i+=3; }
         else if(strncmp(buffer+i,"64",2)    == 0){ value =  6; i+=2; }
         else if(strncmp(buffer+i,"32",2)    == 0){ value =  5; i+=2; }
         else if(strncmp(buffer+i,"16",2)    == 0){ value =  4; i+=2; }
         else if(strncmp(buffer+i,"8",1)     == 0){ value =  3; i++;  }
         else if(strncmp(buffer+i,"4",1)     == 0){ value =  2; i++;  }
         else if(strncmp(buffer+i,"2",1)     == 0){ value =  1; i++;  }
         else if(strncmp(buffer+i,"1",1)     == 0){ value =  0; i++;  }
         if(!whitespace(buffer[i]) && buffer[i] != '\0') {
            fprintf(stderr,"Error: Expecting delay value (a power of 2) on line %i\n",line);
            return 0;
         }
         while(whitespace(buffer[i]))
            i++;
      }

   if(opcodes[o].has_value)
      {
         if(!getOperand(buffer+i, &value, line)) {
            fprintf(stderr,"Expecting value on line %i\n",line);
            return 0;
         }
         if(value > opcodes[o].max_value) {
            fprintf(stderr,"Operand out of range on line %i\n",line);
            return 0;
         }
      }
   else {
      while(whitespace(buffer[i]))
         i++;
      /* Check that the line is terminated correctly */
      if(buffer[i] != '\0' && buffer[i] != ';') {
         fprintf(stderr,"Error: Unexpected data on line %i\n",line);
         return 0;
      }
   }

   if(opcodes[o].has_label)
      memory[memory_used++] = opcodes[o].base_opcode+value/8;
   else
      memory[memory_used++] = opcodes[o].base_opcode+value;
   return 1;
}

/*****************************************************************/
int unresolved_symbols()
{
   struct Symbol *s = firstSymbol;
   int rtn = 0;

   while(s != NULL)
      {
         if(s->resolved == 0)
            {
               fprintf(stderr, "Error: Unresolved Symbol '%s' on line %i\n", s->name, s->firstLine);
               rtn = 1;
            }
         s = s -> next;
      }
   return rtn;
}

/*****************************************************************/
int get_line(FILE *f, int line, char * buffer)
{
   int i,c;

   for(i = 0; i < MEM_SIZE-1; i++)
      {
         c = getc(f);
         if(c == '\n' || c == EOF)
            break;

         if(c != '\r')  /* Ignore CRs */
            buffer[i] = c;
      }

   if(i == MEM_SIZE-1)
      {
         fprintf(stderr, "Warning: Line '%i' to long\n",line);
      }
   while(c != '\n' && c != EOF)
      c = getc(f);

   buffer[i] = '\0';
   if(c == EOF && i == 0)
      return 0;
   return 1;
}

/*****************************************************************/
int main(int argc, char *argv[])
{
   int errored = 0;
   FILE *f;
   char *basename;
   int line = 0;
   char buffer[BUFFER_SIZE];

   if(argc != 2) {
      fprintf(stderr, "An assembler for i3c2 files (see http://hamsterworks.co.nz/mediawiki/index.php/I3C2)\n");
      fprintf(stderr, "\n");
      fprintf(stderr, "Usage: %s filename.i3c2\n", argv[0]);
      return 3;
   }

   if(strlen(argv[1]) < 6 || memcmp(argv[1]+strlen(argv[1])-5,".i3c2",6) != 0)
      {
         fprintf(stderr, "File extension must be '.i3c2'\n");
         return 3;
      }
   basename = (char *)malloc(strlen(argv[1]));
   if(basename == NULL)
      {
         fprintf(stderr,"Out of memory\n");
         return 3;
      }
   memcpy(basename,argv[1],strlen(argv[1])-5);
   basename[strlen(argv[1])-5] = '\0';

   f = fopen(argv[1],"r");
   if(f == NULL)
      {
         fprintf(stderr, "Unable to open input file\n");
         return 3;
      }

   line = 0;
   while(get_line(f, line, buffer))
      {
         line++;
         if(!parse_line(line,buffer))
            {
               fprintf(stderr,"Error on line %i : '%s'\n", line, buffer);
               errored = 1;
            }
      }
   fclose(f);
   if(!errored) if(unresolved_symbols())
                   errored = 1;

   if(!errored) {
      char *namebuffer;
      FILE *f;

      namebuffer = (char*)malloc(strlen(basename)+5);
      if(namebuffer == NULL)
         {
            fprintf(stderr,"Out of memory\n");
            return 3;
         }


      sprintf(namebuffer,"%s.vhd",basename);
      f  = fopen(namebuffer,"w");
      if( f != NULL)
         {
            output_object_code_vhdl(f, basename);
            fclose(f);
         }
      else
         fprintf(stderr,"Unable to open %s\n",namebuffer);

      sprintf(namebuffer,"%s.coe",basename);
      f  = fopen(namebuffer,"w");
      if( f != NULL) {
         output_object_code_coe(f);
         fclose(f);
      }
      else
         fprintf(stderr,"Unable to open %s\n",namebuffer);
      free(namebuffer);
   }

   return 0;
}
/*****************************************************************/
