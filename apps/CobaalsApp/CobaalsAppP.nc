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
  }
}

implementation
{
  enum {
    UART_QUEUE_LEN = 32,
    RADIO_QUEUE_LEN = 32,
  };
  int sendcount = 0;
  message_t  uartQueueBufs[UART_QUEUE_LEN];
  message_t  * ONE_NOK uartQueue[UART_QUEUE_LEN];
  uint8_t    uartIn, uartOut;
  bool       uartBusy, uartFull;

  message_t  radioQueueBufs[RADIO_QUEUE_LEN];
  message_t  * ONE_NOK radioQueue[RADIO_QUEUE_LEN];
  uint8_t    radioIn, radioOut;
  bool       radioBusy, radioFull;

  task void uartSendTask();
  task void radioSendTask();
  task void RF_Configuration_Setting();

  void dropBlink() {
    call Leds.led2Toggle();
  }

  void failBlink() {
    call Leds.led2Toggle();
  }

  event void Boot.booted() {
    uint8_t i = 0;

    for (i = 0; i < UART_QUEUE_LEN; i++)
      uartQueue[i] = &uartQueueBufs[i];
    uartIn = uartOut = 0;
    uartBusy = FALSE;
    uartFull = TRUE;

    for (i = 0; i < RADIO_QUEUE_LEN; i++)
      radioQueue[i] = &radioQueueBufs[i];
    radioIn = radioOut = 0;
    radioBusy = FALSE;
    radioFull = TRUE;

    if (call RadioControl.start() == EALREADY)
      radioFull = FALSE;
    if (call SerialControl.start() == EALREADY)
      uartFull = FALSE;
  }

  event void RadioControl.startDone(error_t error) {
    if (error == SUCCESS) {
      radioFull = FALSE;
      post RF_Configuration_Setting();
    }
  }

  event void SerialControl.startDone(error_t error) {
    if (error == SUCCESS) {
      uartFull = FALSE;
    }
  }

  event void SerialControl.stopDone(error_t error) {}
  event void RadioControl.stopDone(error_t error) {}

  task void RF_Configuration_Setting() {
    /* if (TOS_NODE_ID == 0 || TOS_NODE_ID == 41)
      call CC2420Config.setChannel(15);
    if (TOS_NODE_ID == 1 || TOS_NODE_ID == 40)
      call CC2420Config.setChannel(11); */
    call CC2420Config.setChannel(15);
    call CC2420Config.sync();
  }

  event void CC2420Config.syncDone(error_t error) {}

  uint8_t count = 0;

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

    bool reflectToken = FALSE;

    if (TOS_NODE_ID == PLANT_RX_NODE_ID || TOS_NODE_ID == CONTROLLER_RX_NODE_ID) {
      // Radio to Serial
      if (!uartFull) {
        ret = uartQueue[uartIn];
        uartQueue[uartIn] = msg;

        uartIn = (uartIn + 1) % UART_QUEUE_LEN;

        if (uartIn == uartOut)
        uartFull = TRUE;

        if (!uartBusy) {
          post uartSendTask();
          uartBusy = TRUE;
        }
      }

    } else {
      // Radio to Radio
      atomic {
        if (!radioFull) {
          reflectToken = TRUE;
          ret = radioQueue[radioIn];
          radioQueue[radioIn] = msg;
          if (++radioIn >= RADIO_QUEUE_LEN)
            radioIn = 0;
          if (radioIn == radioOut)
            radioFull = TRUE;

          if (!radioBusy) {
            post radioSendTask();
            radioBusy = TRUE;
          }
        }
      }
    }

    return ret;
  }

  uint8_t tmpLen;

  task void uartSendTask() {
    uint8_t len;
    am_id_t id;
    am_addr_t addr, src;
    message_t* msg;
    am_group_t grp;
    atomic {
      if (uartIn == uartOut && !uartFull) {
        uartBusy = FALSE;
        return;
      }
    }

    msg = uartQueue[uartOut];
    tmpLen = len = call RadioPacket.payloadLength(msg);
    id = call RadioAMPacket.type(msg);
    addr = call RadioAMPacket.destination(msg);
    src = call RadioAMPacket.source(msg);
    grp = call RadioAMPacket.group(msg);
    call UartPacket.clear(msg);
    call UartAMPacket.setSource(msg, src);
    call UartAMPacket.setGroup(msg, grp);

    if (call UartSend.send[id](addr, uartQueue[uartOut], len) == SUCCESS) {
      //call Leds.led1Toggle();

    } else {
      failBlink();
      post uartSendTask();
    }
  }

  event void UartSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    if (error != SUCCESS)
      failBlink();
    else
      atomic
	if (msg == uartQueue[uartOut])
	  {
	    if (++uartOut >= UART_QUEUE_LEN)
	      uartOut = 0;
	    if (uartFull)
	      uartFull = FALSE;
	  }
    post uartSendTask();
  }

  event message_t *UartReceive.receive[am_id_t id](message_t *msg,
						   void *payload,
						   uint8_t len) {
    message_t *ret = msg;
    bool reflectToken = FALSE;

    sendcount++;
    if (sendcount > 290) call Leds.led0Toggle();

    atomic
      if (!radioFull) {
    	  reflectToken = TRUE;
    	  ret = radioQueue[radioIn];
    	  radioQueue[radioIn] = msg;
    	  if (++radioIn >= RADIO_QUEUE_LEN)
    	    radioIn = 0;
    	  if (radioIn == radioOut)
    	    radioFull = TRUE;

    	  if (!radioBusy) {
  	      post radioSendTask();
  	      radioBusy = TRUE;
    	  }
	    }
      else
	      dropBlink();

    if (reflectToken) {
      //call UartTokenReceive.ReflectToken(Token);
    }

    return ret;
  }

  task void radioSendTask() {
    uint8_t len;
    am_id_t id;
    am_addr_t addr,source;
    message_t* msg;

    atomic
      if (radioIn == radioOut && !radioFull) {
    	  radioBusy = FALSE;
    	  return;
	    }

    msg = radioQueue[radioOut];
    len = call UartPacket.payloadLength(msg);
    addr = call UartAMPacket.destination(msg);
    source = call UartAMPacket.source(msg);
    id = call UartAMPacket.type(msg);

    call RadioPacket.clear(msg);
    call RadioAMPacket.setSource(msg, source);

    if (call RadioSend.send[id](addr, msg, len) == SUCCESS) {
      //call Leds.led0Toggle();
    } else {
	    failBlink();
	    post radioSendTask();
    }
  }

  event void RadioSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    if (error != SUCCESS)
      failBlink();
    else
      atomic
	if (msg == radioQueue[radioOut])
	  {
	    if (++radioOut >= RADIO_QUEUE_LEN)
	      radioOut = 0;
	    if (radioFull)
	      radioFull = FALSE;
	  }

    post radioSendTask();
  }
}
