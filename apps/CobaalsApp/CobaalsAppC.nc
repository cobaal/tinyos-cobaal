#define NEW_PRINTF_SEMANTICS
#include "printf.h"

configuration CobaalsAppC {
}
implementation {
  components MainC, CobaalsAppP, LedsC;
  components ActiveMessageC as Radio, SerialActiveMessageC as Serial;
  components CC2420ActiveMessageC;
  components CC2420ControlC;
  components PrintfC;
  components SerialStartC;

  MainC.Boot <- CobaalsAppP;

  CobaalsAppP.RadioControl -> Radio;
  CobaalsAppP.SerialControl -> Serial;

  CobaalsAppP.UartSend -> Serial;
  CobaalsAppP.UartReceive -> Serial.Receive;
  CobaalsAppP.UartPacket -> Serial;
  CobaalsAppP.UartAMPacket -> Serial;

  CobaalsAppP.RadioSend -> Radio;
  CobaalsAppP.RadioReceive -> Radio.Receive;
  CobaalsAppP.RadioSnoop -> Radio.Snoop;
  CobaalsAppP.RadioPacket -> Radio;
  CobaalsAppP.RadioAMPacket -> Radio;

  CobaalsAppP.CC2420Packet -> CC2420ActiveMessageC;
  CobaalsAppP.CC2420Config -> CC2420ControlC;

  CobaalsAppP.Leds -> LedsC;
}
