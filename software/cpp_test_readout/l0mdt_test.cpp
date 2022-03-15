//
// simple test of L0MDT DAQ with picoblaze-ebus interface
//


#include <string>
#include <iostream>
#include <algorithm>
#include <tclap/CmdLine.h>
#include "serial_command.hh"

using namespace TCLAP;
using namespace std;

int main(int argc, char** argv)
{

  try {  

    // Define the command line object.
    CmdLine cmd("Command description message", ' ', "0.9");

    // USB port
    ValueArg<string> portArg("p","port","Serial port name",false,"/dev/ttyUSB1","port");
    cmd.add( portArg );

    ValueArg<string> baudArg("b","baud","Baud rate",false,"9600","baud");
    cmd.add( baudArg );
    
    // Parse the args.
    cmd.parse( argc, argv );

    // Get the value parsed by each arg. 
    string port = portArg.getValue();
    string baud = baudArg.getValue();

    cout << "Connecting to " << port << " at " << baud << endl;

    string ser_cmd;			// command to send
    string ser_resp;			// response received
  
    SerialPort sp( port); // connect to the port
    sp.SetBaudRate( LibSerial::BaudRate::BAUD_9600); // set baud rate

    while( 1) {

      cout << "Enter command: ";	// get command from user
      getline( cin, ser_cmd);

      vector<string> rv = command_vector( sp, ser_cmd);

      if( rv.size() == 0)
	cout << "(empty)" << endl;
      else {
	for( unsigned i=0; i<rv.size(); i++)
	  cout << i << " = " << rv[i] << endl;
      }
    }
    

  } catch (ArgException &e)  // catch any exceptions
    { cerr << "error: " << e.error() << " for arg " << e.argId() << endl; }
}

