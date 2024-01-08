proc write_config_mmi {filename} {
	set proj [current_project]
	set fileout [open $filename "w"]

   set tmp [get_property SITE [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ BMEM.*.* && PARENT =~  "config_rom_inst" && NAME =~  "*data_reg_0*" } ] ]
   set tmp_list [split $tmp "_"]
	set site0 [lindex $tmp_list 1]

   set tmp [get_property SITE [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ BMEM.*.* && PARENT =~  "config_rom_inst" && NAME =~  "*data_reg_1*" } ] ]
   set tmp_list [split $tmp "_"]
	set site1 [lindex $tmp_list 1]

   set tmp [get_property SITE [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ BMEM.*.* && PARENT =~  "config_rom_inst" && NAME =~  "*data_reg_2*" } ] ]
   set tmp_list [split $tmp "_"]
	set site2 [lindex $tmp_list 1]

   set tmp [get_property SITE [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ BMEM.*.* && PARENT =~  "config_rom_inst" && NAME =~  "*data_reg_3*" } ] ]
   set tmp_list [split $tmp "_"]
	set site3 [lindex $tmp_list 1]

	puts $fileout "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
	puts $fileout "<MemInfo Version=\"1\" Minor=\"0\">"
	puts $fileout "  <Processor Endianness=\"Little\" InstPath=\"dummy\">"
	puts $fileout "    <AddressSpace Name=\"config_rom\" Begin=\"0\" End=\"16383\">"
	puts $fileout "      <BusBlock>"
	puts $fileout "        <BitLane MemType=\"RAMB32\" Placement=\"$site3\">"
	puts $fileout "          <DataWidth MSB=\"7\" LSB=\"6\"/>"
	puts $fileout "          <AddressRange Begin=\"0\" End=\"16383\"/>"
	puts $fileout "          <Parity ON=\"false\" NumBits=\"0\"/>"
	puts $fileout "        </BitLane>"
	puts $fileout "        <BitLane MemType=\"RAMB32\" Placement=\"$site2\">"
	puts $fileout "          <DataWidth MSB=\"5\" LSB=\"4\"/>"
	puts $fileout "          <AddressRange Begin=\"0\" End=\"16383\"/>"
	puts $fileout "          <Parity ON=\"false\" NumBits=\"0\"/>"
	puts $fileout "        </BitLane>"
	puts $fileout "        <BitLane MemType=\"RAMB32\" Placement=\"$site1\">"
	puts $fileout "          <DataWidth MSB=\"3\" LSB=\"2\"/>"
	puts $fileout "          <AddressRange Begin=\"0\" End=\"16383\"/>"
	puts $fileout "          <Parity ON=\"false\" NumBits=\"0\"/>"
	puts $fileout "        </BitLane>"
	puts $fileout "        <BitLane MemType=\"RAMB32\" Placement=\"$site0\">"
	puts $fileout "          <DataWidth MSB=\"1\" LSB=\"0\"/>"
	puts $fileout "          <AddressRange Begin=\"0\" End=\"16383\"/>"
	puts $fileout "          <Parity ON=\"false\" NumBits=\"0\"/>"
	puts $fileout "        </BitLane>"
	puts $fileout "      </BusBlock>"
	puts $fileout "    </AddressSpace>"
	puts $fileout " </Processor>"
	puts $fileout " <Config>"
	puts $fileout "   <Option Name=\"Part\" Val=\"xc7a15tcsg324-1\"/>"
	puts $fileout " </Config>"
	puts $fileout "</MemInfo>"
	close $fileout
}

write_config_mmi config_rom.mmi
