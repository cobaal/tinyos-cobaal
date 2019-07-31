#include "AM.h"
#include "Serial.h"
#include "CobaalsApp.h"

module CobaalsAppP @safe() {
  uses {
    interface Boot;
    interface SplitControl as SerialControl;
    interface SplitControl as RadioControl;

    interface AMSend as UartSend[am_id_t id];
    interface Receive as UartReceive[am_id_t id];
    interface Packet as UartPacket;
    interface AMPacket as UartAMPacket;

    interface AMSend as RadioSend[am_id_t id];
    interface Receive as RadioReceive[am_id_t id];
    interface Receive as RadioSnoop[am_id_t id];
    interface Packet as RadioPacket;
    interface AMPacket as RadioAMPacket;

    interface CC2420Packet;
    interface CC2420Config;

    interface Leds;
    interface Timer<TMilli>;
  }
}

implementation
{
  int sendcount = 0;

  void dropBlink() {
    /* call Leds.led2Toggle(); */
  }

  void failBlink() {
    /* call Leds.led2Toggle(); */
  }

  event void Boot.booted() {
    if (call RadioControl.start() == EALREADY) {}
    if (call SerialControl.start() == EALREADY) {}
  }

  event void RadioControl.startDone(error_t error) {
    if (error == SUCCESS) {
      /* call CC2420Config.setChannel(15);
      call CC2420Config.sync(); */
    }
  }

  event void SerialControl.startDone(error_t error) {
    if (error == SUCCESS) {
    }
  }

  event void SerialControl.stopDone(error_t error) {}
  event void RadioControl.stopDone(error_t error) {}

  event void CC2420Config.syncDone(error_t error) {}

  message_t* ONE receive(message_t* ONE msg, void* payload, uint8_t len);

  event message_t *RadioSnoop.receive[am_id_t id](message_t *msg,
						    void *payload,
						    uint8_t len) {
    return receive(msg, payload, len);
  }

  event message_t *RadioReceive.receive[am_id_t id](message_t *msg,
						    void *payload,
						    uint8_t len) {
    return receive(msg, payload, len);
  }

  message_t* receive(message_t *msg, void *payload, uint8_t len) {
    message_t *ret = msg;
    am_id_t id;
    am_addr_t addr, src;
    am_group_t grp;

    if (TOS_NODE_ID == PLANT_RX_NODE_ID || TOS_NODE_ID == CONTROLLER_RX_NODE_ID) {
      // Radio to Serial
      atomic {
        id = call RadioAMPacket.type(msg);
        addr = call RadioAMPacket.destination(msg);
        src = call RadioAMPacket.source(msg);
        grp = call RadioAMPacket.group(msg);

        call UartPacket.clear(msg);
        call UartAMPacket.setSource(msg, src);
        call UartAMPacket.setGroup(msg, grp);

        call UartSend.send[id](addr, msg, len);
      }

    } else {
      // Radio to Radio
      atomic {
        id = call RadioAMPacket.type(msg);
        addr = call RadioAMPacket.destination(msg);
        src = call RadioAMPacket.source(msg);
        grp = call RadioAMPacket.group(msg);

        call RadioPacket.clear(msg);
        call RadioAMPacket.setSource(msg, src);
        call RadioAMPacket.setGroup(msg, grp);

        call RadioSend.send[id](addr, msg, len);
      }
    }

    return ret;
  }

  event void UartSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    if (error != SUCCESS)
      failBlink();
  }

  event message_t *UartReceive.receive[am_id_t id](message_t *msg,
						   void *payload,
						   uint8_t len) {
    message_t *ret = msg;
    am_addr_t addr,source;

    /* atomic {
      sendcount++;
      if (sendcount > 290) {
        call Leds.led0Toggle();
      }
    } */

    atomic {
      addr = call UartAMPacket.destination(msg);
      source = call UartAMPacket.source(msg);

      call RadioPacket.clear(msg);
      call RadioAMPacket.setSource(msg, source);

      call RadioSend.send[id](addr, msg, len);
    }

    return ret;
  }

  event void RadioSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    if (error != SUCCESS) {
      failBlink();
    } else {
      call RadioControl.stop();
      call Timer.startOneShot(15);
    }
  }

  event void Timer.fired() {
    call RadioControl.start();
  }
}
