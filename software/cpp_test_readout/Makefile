
all: serial_demo read_write_demo

clean:
	rm -f *.o *~ \#* serial_demo serial_blink read_write_demo lookup_test

serial_demo.o: serial_demo.cpp serial_command.hh

read_write_demo.o: read_write_demo.cpp

serial_command.o: serial_command.cc serial_command.hh

serial_demo: serial_demo.o serial_command.o
	g++ -o serial_demo serial_demo.o serial_command.o -lserial

read_write_demo: read_write_demo.o serial_command.o serial_read_write.o
	g++ -o read_write_demo read_write_demo.o serial_command.o serial_read_write.o -lserial

serial_read_write.o: serial_read_write.cc serial_read_write.hh
