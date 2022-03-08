#
# process custom types
#

VHDL = ebus_function_pkg.vhd test.vhd

all: types

types: ebus_types.vhd 

clean:
	rm -f *.o *~ *.cf *.vcd *.ghw *.db *.ready ../src/ebus_types.vhd ebus_types_textio.vhd analyze.ready test

# create the VHDL types from the YAML file using yml2hdl
ebus_types.vhd: ebus_types.yml
	python3 ../../yml2hdl/yml2hdl.py -f -I 0.2 ../src/ebus_types.yml
