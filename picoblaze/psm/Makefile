#
# build picoblaze firmware
#
PBASM = /home/hazen/.local/bin/opbasm
PERL = /usr/bin/perl

all: clean my_ROM.vhd

clean:
	rm -f *.fmt *.hex *.log my_ROM.vhd *.mon *.uue

monitor.uue: monitor.hex uart_interface_routines.psm uart_utility.psm memory_utility.psm
	$(PERL) hex_to_uue.pl monitor.hex monitor.uue

copyh: monitor.uue
	scp monitor.uue hertz:tmp

my_ROM.vhd: monitor.hex my_ROM_template.vhd
	echo "my_ROM.vhd"
	$(PERL) hex_to_rom.pl monitor.hex my_ROM_template.vhd 2048 > my_ROM.vhd

monitor.hex: monitor.psm
	echo "building monitor.hex"
	$(PBASM) -6 -x monitor.psm
