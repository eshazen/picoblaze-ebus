// serial_read_write.hh
//
// Simple functions to read and write individual eBus registers on the board
// (intended to be replaceable easily with future IPBus Ethernet calls)
//
// uint32_t serial_register_read( SerialPort& sp, uint32_t addr)
// serial_register_write( SerialPort& sp, uint32_t addr, uint32_t data)
//

#include "serial_command.hh"
#include <stdint.h>

uint32_t serial_register_read( SerialPort& sp, uint32_t addr);
void serial_register_write( SerialPort& sp, uint32_t addr, uint32_t data);

