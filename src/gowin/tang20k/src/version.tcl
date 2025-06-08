set version [exec git rev-parse --short HEAD]
set fd [open "src[file separator]version_config_pack.vhd" w+]

puts $fd "library ieee;"
puts $fd "use ieee.std_logic_1164.all;"
puts $fd ""
puts $fd "package version_config_pack is"
puts $fd "    constant G_CONFIG_VERSION : std_logic_vector(31 downto 0) := x\"0$version\";"
puts $fd "end version_config_pack;"
puts $fd ""
puts $fd "package body version_config_pack is"
puts $fd "end version_config_pack;"

close $fd
