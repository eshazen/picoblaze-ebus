//
// simple test of L0MDT DAQ with picoblaze-ebus interface
//

// ratio of rate meter sample period in system clocks
// (clock is 100MHz; currently samples for 10M clocks)
#define RATE_METER_PER 10e6
#define SYS_CLK_RATE 100e6

#define PIPE_CLK_MULTIPLE 8

#include <stdlib.h>
#include <unistd.h>
#include <inttypes.h>

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


void decode_data( string s);


int main(int argc, char** argv)
{

  try {  

    // Define the command line object.
    CmdLine cmd("Command description message", ' ', "0.9");

    ValueArg<string> dataArg("d","data","Number of data words",false,"64","words");                 cmd.add( dataArg );
    ValueArg<string> portArg("p","port","Serial port name",false,"/dev/ttyUSB1","port");            cmd.add( portArg );
    ValueArg<string> baudArg("b","baud","Baud rate",false,"9600","baud");                           cmd.add( baudArg );
    ValueArg<string> trigArg("t","trig_prob","Trigger Probability per BX",true,"0.01","fraction");  cmd.add( trigArg);
    ValueArg<string> hitArg("m","hit_prob","Hit Probability per clock",true,"1.0","fraction");      cmd.add( hitArg);

    // Parse the args.
    cmd.parse( argc, argv );

    // Get the value parsed by each arg. 
    string port = portArg.getValue();
    string baud = baudArg.getValue();
    double trig_p = atof(trigArg.getValue().c_str());
    double hit_p = atof(hitArg.getValue().c_str());
    unsigned dwords = strtoul( dataArg.getValue().c_str(), NULL, 0);

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
    sprintf( buff, "w 1 %08x", hit_r);
    rv = command_vector( sp, buff);
    rv = command_vector( sp, "w 3000000a 1");

    cout << "Waiting for rate measurement..." << endl;

    usleep( 250000);

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

    // adjust the measured rates for rate meter sampling
    trig_m *= SYS_CLK_RATE/RATE_METER_PER;
    hit_m *= SYS_CLK_RATE/RATE_METER_PER;

    // calculate the expected rates
    double trig_c = trig_p * (SYS_CLK_RATE / PIPE_CLK_MULTIPLE);
    double hit_c = hit_p * SYS_CLK_RATE;

    printf("Expected trigger rate (Hz) = %8.0f  Hit rate (Hz) = %8.0f\n", trig_c, hit_c);
    printf("Measured trigger rate (Hz) = %8d  Hit rate (Hz) = %8d\n", trig_m, hit_m);

    // trigger readout
    command_vector( sp, "w 3000000a 1"); // trigger readout

    // check addresses
    rv = command_vector( sp, "r 30000008 2");

    vt = split_string( rv[0], ' ');
    unsigned write_a = strtoul( vt[1].c_str(), NULL, 16) & 0xffff;
    vt = split_string( rv[1], ' ');
    unsigned read_a = strtoul( vt[1].c_str(), NULL, 16) & 0xffff;

    printf("Write addr = %08x  Read addr = %08x\n", write_a, read_a);
    if( write_a != 0x3ff) {
      printf("Write buffer not full\n");
      exit(1);
    }

    // read data
    sprintf( buff, "d 0 %x", dwords);
    rv = command_vector( sp, buff); // read data words

    printf("%ld words received\n", rv.size());

    for( int i=0; i<rv.size(); i++)
      decode_data( rv[i]);

  } catch (ArgException &e)  // catch any exceptions
    { cerr << "error: " << e.error() << " for arg " << e.argId() << endl; }
}



//
// decode a string with (9) 32-bit words
// first is word count
// then a 256-bit word formatted as 8 32-bit words
// Upper 230 bits are FELIX data
// Lower  26 bits are timestamp
//
void decode_data( string s)
{
  uint64_t w[8];
  uint64_t ws[8];

  vector<string> vw = split_string( s, ' ');

  if( vw.size() != 9) {
    cout << "error decoding data: " << s << endl;
    exit(1);
  }

  for( int i=0; i<8; i++)
    w[7-i] = strtoul( vw[i+1].c_str(), NULL, 16);

  // get timestamp
  uint32_t ts = w[0] & 0x3ffffff;

  // get word type
  uint8_t wt = (w[7] >> 28) & 0xf;

  // shift raw MDT data
  for( int i=0; i<7; i++) {
    ws[i] = (((w[i] >> 26) & 0x3f) | (w[i+1] << 6)) & 0xffffffff;
  }

//  printf("Raw:  ");
//  for( int i=0; i<8; i++)
//    printf(" %08" PRIx64, w[7-i]);
//  printf("\n");
//  printf("Shf:  ");
//  for( int i=0; i<7; i++)
//    printf(" %08" PRIx64, ws[6-i]);
//  printf("\n");

  // extract header/trailer data
  uint64_t htd = ((w[0] >> 26) & 0x3f) | (w[1] << 6);

  uint16_t wmu = (htd >> 36) & 0xff;
  uint16_t evn = htd & 0xfff;
  uint16_t bcn = (htd >> 12) & 0xfff;
  uint16_t orn = (htd >> 24) & 0xfff;

  // extract data hits
  uint64_t h0 = ws[0] | ((ws[1] << 16) & 0xffff);
  uint64_t h1 = ((ws[1] >> 16) & 0xffff) | (ws[2] << 16);
  uint64_t h2 = ws[3] | ((ws[4] << 16) & 0xffff);
  uint64_t h3 = ((ws[4] >> 16) & 0xffff) | (ws[5] << 16);

  if( wt == 4)
    printf("\n");
  printf("TS=%08x ", ts);

  switch( wt) {
  case 4:
    putc( 'H', stdout);
    printf(" WMU=%02x EvN=%03x BcN=%03x OrN=%03x ", wmu, evn, bcn, orn);
    
    break;
  case 8:
    putchar('D');
    printf(" %016" PRIx64, h0);
    printf(" %016" PRIx64, h1);
    printf(" %016" PRIx64, h2);
    printf(" %016" PRIx64, h3);

    break;
  case 0xc:
    putchar('T');
    printf(" WMU=%02x EvN=%03x BcN=%03x OrN=%03x ", wmu, evn, bcn, orn);

    break;
  default:
    putchar('?');

  }

  printf("\n");
    

}
