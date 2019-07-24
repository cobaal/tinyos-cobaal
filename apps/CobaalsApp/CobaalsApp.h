#ifndef COBAALSAPP_H
#define COBAALSAPP_H

enum {
  PLANT_TX_NODE_ID = 40,
  PLANT_RX_NODE_ID = 41,
  CONTROLLER_TX_NODE_ID = 0,
  CONTROLLER_RX_NODE_ID = 1
};

typedef nx_struct CobaalMsg {
  nx_uint64_t value_1;
  nx_uint64_t value_2;
  nx_uint64_t code;
  nx_uint8_t sequence;
} CobaalMsg;

#endif
