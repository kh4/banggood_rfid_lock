This is a alternative firmware for
  http://www.banggood.com/RFID-Security-Reader-Entry-Door-Lock-keypad-Access-Control-System10-Pcs-Keys-p-982752.html

the original code has all the locking logic on the keypad which is highly unsecure since the lock can be bypassed by simple piece of wire.

This code will make the keypad/reader 'dumb' making it only act as terminal which is connected to controller on more secure location via serial (9600bps) interface.

The code implements
===================
 - scanning of the keypad
 - control of LEDs (yellow,green)
 - control of buzzer
 - control of relay
 - RFID detection and reading

Text based protocol
===================
1) Commands to the keypad unit are single letter
 - 'Y' / 'y' : toggle yellow LED on/off
 - 'G' / 'g' : toggle green LED on/off
 - 'R' / 'r' : toggle relay on/off
 - 'B' / 'b' : toggle buzzer on/off
 All commands are acked by "OK\r\n" sequence.

2) Messages sent by the keypad
 - "Bx\r\n" button press, x is "1234567890*#"
 - "Txxxxxxxxxx\r\n" RFID tag detected xxxxxxxxxx is tag data
 - "Terr\r\n" RFID tag parity error

Needed HW modifications
=======================

1) for programming the PIC16F73 controller ISP wires need to be added
   I used PICKIT3 for programming

2) the MCU TX/RX pins are not available by default so these need to be wired out, I connected them to WG0 and WG1 (removing the diodes to isolate them). See images/TXRX_wires.jpg.

3) the socketed EEPROM (24c256) can be removed as it is not utilized.

Compilation
===========

The code/main.asm file can be directly compiled with MPLAB IDE.

Uploading
=========

To upload the code onto the keypad, ISP wires need to be added. Any PIC16F73 capable programmer can be used e.g. PICKIT 3. At least on my unit the original firmware was protected so backing up the original firmware is not possible.
