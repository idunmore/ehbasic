# Builds a OneROM (https://www.onerom.org) image for my version of
# EhBASIC, using whatever options the version of ../bin/basic.bin was
# last assembled for.
#
# Targets Slot 0 (default) on a OneROM Fire-28, using an AT27C256 EPROM
# chip target, and including the USB plugin using the latest version of
# the OneROM firmware (which is automatically downloaded).
#
# A stock BE6502 is wired for an AT27C256 EEPROM; you can change the
# value of type=27256 to 28256 if that is how you're setup.  I am using
# the AT27CXXX pinout for compatability with both picoROM and OneROM.
#
# Requires the OneROM CLI installed and available on your PATH.
echo "Downloading latest OneROM firmware and building OneROM image ..."
onerom firmware build --board fire-28-a --plugin usb --slot file=../bin/basic.bin,type=27256 --out ehbasic.rom