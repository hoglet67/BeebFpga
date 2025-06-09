proc comp_file {file1 file2} {
    # optimization: check file size first
    set equal 0
    if {[file size $file1] == [file size $file2]} {
        set fh1 [open $file1 r]
        set fh2 [open $file2 r]
        set equal [string equal [read $fh1] [read $fh2]]
        close $fh1
        close $fh2
    }
    return $equal
}

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

if {![file exists $name.vhd] || ![comp_file $name.tmp $name.vhd]} {
    file copy -force $name.tmp $name.vhd
}

file delete $name.tmp
