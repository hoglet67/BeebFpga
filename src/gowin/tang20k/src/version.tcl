try {
    set version [exec git rev-parse --short=8 HEAD]
} trap CHILDSTATUS {} {
    set version "00000000"
}

try {
    set dirty [exec git status --untracked-files=no --porcelain]
} trap CHILDSTATUS {} {
    set dirty ""
}

if {$dirty eq ""} {
    set dirty "false"
} else {
    set dirty "true"
}

set name "src[file separator]version_config_pack"

set fd [open "$name.tmp" w+]

puts $fd "library ieee;"
puts $fd "use ieee.std_logic_1164.all;"
puts $fd ""
puts $fd "package version_config_pack is"
puts $fd "    constant G_CONFIG_VERSION : std_logic_vector(31 downto 0) := x\"$version\";"
puts $fd "    constant G_CONFIG_DIRTY   : boolean := $dirty;"
puts $fd "end version_config_pack;"
puts $fd ""
puts $fd "package body version_config_pack is"
puts $fd "end version_config_pack;"

close $fd

try {
    exec cmp $name.tmp $name.vhd
} trap CHILDSTATUS {} {
    file copy -force $name.tmp $name.vhd
} finally {
    file delete $name.tmp
}
