//
// simple test of L0MDT DAQ with picoblaze-ebus interface
//


#include <stdlib.h>
#include <unistd.h>

#include <string>
#include <iostream>
#include <algorithm>
#include <tclap/CmdLine.h>
#include "serial_command.hh"

using namespace TCLAP;
using namespace std;

// split a string into a vector of tokens using a separator
vector<string> split_string(string s, char sep)
{
  string tmp;
  stringstream ss(s);
  vector<string> rv;
  while (getline(ss, tmp, sep))
    rv.push_back(tmp);
  return (rv);
}

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

    ValueArg<string> trigArg("t","trig_prob","Trigger Probability per BX",true,"0.01","fraction");
    cmd.add( trigArg);

    ValueArg<string> hitArg("m","hit_prob","Hit Probability per clock",true,"1.0","fraction");
    cmd.add( hitArg);

    // Parse the args.
    cmd.parse( argc, argv );

    // Get the value parsed by each arg. 
    string port = portArg.getValue();
    string baud = baudArg.getValue();
    double trig_p = atof(trigArg.getValue().c_str());
    double hit_p = atof(hitArg.getValue().c_str());

    unsigned trig_r = (double)0xffffffff * trig_p;
    unsigned hit_r = (double)0xffffffff * hit_p;

    printf("Trig_R = 0x%08x  Hit_R = 0x%08x\n", trig_r, hit_r);

    cout << "Connecting to " << port << " at " << baud << endl;

    SerialPort sp( port); // connect to the port
    sp.SetBaudRate( LibSerial::BaudRate::BAUD_9600); // set baud rate

    // initialize the logic
    vector<string> rv;
    char buff[256];

    cout << "Initializing..." << endl;

    rv = command_vector( sp, "o 10 0"); // issue soft reset
    sprintf( buff, "w 0 %08x", trig_r);
    rv = command_vector( sp, buff);
    sprintf( buff, "w 0 %08x", hit_r);
    rv = command_vector( sp, buff);
    rv = command_vector( sp, "w 3000000a 1");

    cout << "Waiting for rate measurement..." << endl;

    sleep(2);

    cout << "Reading rates..." << endl;
    
    rv = command_vector( sp, "r 10000000 4");

    if( rv.size() != 4) {
      cout << "(empty)" << endl;
      exit(1);
    }

    vector<string> vt;
    cout << "Parsing: " << rv[1] << endl;
    vt = split_string( rv[1], ' ');
    if( vt.size() != 2) {
      printf("Expected size 2, got size %zd\n", vt.size());
      exit(1);
    }
    unsigned trig_m = strtoul( vt[1].c_str(), NULL, 16);


    cout << "Parsing: " << rv[2] << endl;
    vt = split_string( rv[2], ' ');
    if( vt.size() != 2) {
      printf("Expected size 2, got size %zd\n", vt.size());
      exit(1);
    }

    unsigned hit_m = strtoul( vt[1].c_str(), NULL, 16);

    printf("Trigger rate (Hz) = %d  Hit rate (Hz) = %d\n", trig_m, hit_m);

  } catch (ArgException &e)  // catch any exceptions
    { cerr << "error: " << e.error() << " for arg " << e.argId() << endl; }
}

