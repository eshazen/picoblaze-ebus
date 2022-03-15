//
// serial_demo.cpp
//
// demostration of the serial library (libserial-dev package)
// read commands from the terminal, send to device, display response
// some discrepancies found from the LibSerial documentation :(
//
// There is no function SerialPort.Write( buffer, length)
// Instead there is SerialPort.Write( vector<uint8_t>)
//
// Read timeout throws an exception LibSerial::ReadTimeout'
//

#include "serial_command.hh"

using namespace LibSerial;
using namespace std;

int main() {

  string cmd;			// command to send
  string resp;			// response received
  
  SerialPort sp( "/dev/ttyACM0"); // connect to the port
  sp.SetBaudRate( LibSerial::BaudRate::BAUD_9600); // set baud rate

  while( 1) {

    cout << "Enter command: ";	// get command from user
    getline( cin, cmd);

    vector<string> rv = command_vector( sp, cmd);

    if( rv.size() == 0)
      cout << "(empty)" << endl;
    else {
      for( unsigned i=0; i<rv.size(); i++)
	cout << i << " = " << rv[i] << endl;
    }
  }
  
}
