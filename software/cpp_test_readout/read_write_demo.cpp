//
// read_write_demo.cpp
//

#include "serial_command.hh"
#include "serial_read_write.hh"
#include <sstream>

using namespace LibSerial;
using namespace std;

// split a string into a vector of tokens using a separator
vector<string> split_string( string s, char sep) {
  string tmp;
  stringstream ss(s);
  vector<string> rv;
  while( getline(ss, tmp, sep))
    rv.push_back(tmp);
  return(rv);
}


int main() {

  uint32_t addr, data;
  string cmd;
  vector<string> v;

  SerialPort sp( "/dev/ttyACM0"); // connect to the port
  sp.SetBaudRate( LibSerial::BaudRate::BAUD_9600); // set baud rate

  cout << "Enter 'R <addr>' or  'W <addr> <data>'" << endl;
  cout << "  decimal or 0xHEX" << endl;

  while( 1) {

    cout << "> ";
    getline( cin, cmd);
    v = split_string( cmd, ' ');
    if( v.size() > 1) {
      addr = strtoul( v[1].c_str(), NULL, 0);
      if( v.size() > 2) {
	data = strtoul( v[2].c_str(), NULL, 0);
	printf("Got data 0x%x\n", data);
      }
    }

    if( v[0] == "r" || v[0] == "R") {
      data = serial_register_read( sp, addr);
      printf("Read from 0x%x\n", addr);
      printf("Read data = %d (0x%08x)\n", data, data);
    } else if( v[0] == "w" || v[0] == "W") {
      printf("Write 0x%x to 0x%x\n", data, addr);
      serial_register_write( sp, addr, data);
    } else {
      cout << "Unknown command: " << v[0] << endl;
    }
  }
}
