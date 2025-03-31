# heavily edited version of https://github.com/mfischer/Altera-Makefile

	QUARTUS_SH=quartus_sh.exe
	QUARTUS_MAP=quartus_map.exe
	QUARTUS_FIT=quartus_fit.exe
	QUARTUS_ASM=quartus_asm.exe
	QUARTUS_PGM=quartus_pgm.exe
	QUARTUS_CPF=quartus_cpf.exe


###################################################################
# Project Configuration: 
# 
# Specify the name of the design (project) and the Quartus II
# Settings File (.qsf)
###################################################################

PROJECT = bbc_micro_de0
SCRIPTS = ../../../scripts

###################################################################
# Main Targets
#
# all: build everything
# clean: remove output files and database
# program: program your device with the compiled design
###################################################################

all:: output_files/$(PROJECT).asm.rpt Makefile.deps

clean:
	rm -rf *.rpt *.chg smart.log *.htm *.eqn *.pin *.pof db incremental_db
	rm output_files/$(PROJECT).sof
	rm output_files/$(PROJECT).pof


map: $(PROJECT).map.rpt
fit: $(PROJECT).fit.rpt
asm: $(PROJECT).asm.rpt
sta: $(PROJECT).sta.rpt

###################################################################
# Executable Configuration
###################################################################

MAP_ARGS = --read_settings_files=on

FIT_ARGS = --read_settings_files=on
ASM_ARGS =

###################################################################
# Target implementations
###################################################################

STAMP = echo done >


output_files/$(PROJECT).map.rpt fit.chg: $(PROJECT).qsf 
	$(QUARTUS_MAP) $(MAP_ARGS) $(PROJECT)
	$(STAMP) fit.chg

output_files/$(PROJECT).fit.rpt asm.chg: $(PROJECT).qsf output_files/$(PROJECT).map.rpt fit.chg
	$(QUARTUS_FIT) $(FIT_ARGS) $(PROJECT)
	$(STAMP) asm.chg

output_files/$(PROJECT).sof output_files/$(PROJECT).asm.rpt: $(PROJECT).qsf output_files/$(PROJECT).fit.rpt asm.chg
	$(QUARTUS_ASM) $(ASM_ARGS) $(PROJECT)
	{ if [ -e version.tag ]; then cat version.tag; fi ; date +'_%Y%m%d_%H%M%S'; } | tr -d "\r\n" | tr ":" "_" > output_files/$(PROJECT).sof.ver
	cp output_files/$(PROJECT).sof output_files/$(PROJECT).$$(cat output_files/$(PROJECT).sof.ver).sof


###################################################################
# Programming the device
###################################################################

program: output_files/$(PROJECT).sof reprogram

reprogram:
	$(QUARTUS_PGM) --no_banner --mode=jtag -o "P;output_files/$(PROJECT).sof"

program-pof: $(PROJECT).pof
	$(QUARTUS_PGM) --no_banner --mode=jtag -o "BVP;$(PROJECT).pof"

program-perm:: output_files/$(PROJECT).jic
	$(QUARTUS_PGM) --no_banner --mode=jtag -o "IP;output_files/$(PROJECT).jic"

output_files/$(PROJECT).jic: output_files/$(PROJECT).sof	
	$(QUARTUS_CPF) -c $(PROJECT).cof
	cp output_files/$(PROJECT).jic output_files/$(PROJECT).$$(cat output_files/$(PROJECT).sof.ver).jic



###################################################################
# Crude attempt at automatic dependencies
###################################################################


Makefile.deps: $(PROJECT).qsf
	perl $(SCRIPTS)/getdeps.pl output_files/$(PROJECT).map.rpt VHDL_FILE QIP_FILE < $(PROJECT).qsf > Makefile.deps
	perl $(SCRIPTS)/getdeps.pl output_files/$(PROJECT).fit.rpt SDC_FILE < $(PROJECT).qsf >> Makefile.deps
	perl $(SCRIPTS)/getdeps.pl version.vhd VHDL_FILE QIP_FILE < $(PROJECT).qsf >> Makefile.deps

include Makefile.deps