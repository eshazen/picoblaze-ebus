
#include "serial_read_write.hh"

uint32_t serial_register_read( SerialPort& sp, uint32_t addr) {
  char cmd[32];
  vector<string> rv;
  uint32_t v;
  
  snprintf( cmd, sizeof(cmd), "R %x", addr);
  rv = command_vector( sp, cmd);
  if( rv.size() != 1) {
    cerr << "ERROR!  No/incorrect response from command " << cmd << endl;
    exit(1);
  }
  v = strtoul( rv[0].c_str(), NULL, 16);
  return v;
}


void serial_register_write( SerialPort& sp, uint32_t addr, uint32_t data) {
  char cmd[32];
  vector<string> rv;
  snprintf( cmd, sizeof(cmd), "W %x %x", addr, data);
  rv = command_vector( sp, cmd);
  if( rv.size()) {
    cerr << "ERROR!  No/incorrect response from command " << cmd << endl;
    exit(1);
  }


}
