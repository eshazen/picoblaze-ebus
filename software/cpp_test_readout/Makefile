
all: serial_demo.exe read_write_demo.exe l0mdt_test.exe

clean:
	rm -f *.exe *.o *~ \#*

l0mdt_test.o: l0mdt_test.cpp

l0mdt_test.exe: l0mdt_test.o serial_command.o
	g++ -o l0mdt_test.exe l0mdt_test.o serial_command.o -lserial

serial_demo.o: serial_demo.cpp serial_command.hh

read_write_demo.o: read_write_demo.cpp

serial_command.o: serial_command.cc serial_command.hh

serial_demo.exe: serial_demo.o serial_command.o
	g++ -o serial_demo.exe serial_demo.o serial_command.o -lserial

read_write_demo.exe: read_write_demo.o serial_command.o serial_read_write.o
	g++ -o read_write_demo.exe read_write_demo.o serial_command.o serial_read_write.o -lserial

serial_read_write.o: serial_read_write.cc serial_read_write.hh
