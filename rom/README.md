# OneROM Tools
[OneROM](https://onerom.org) is an [E]EPROM emulator.

When developing software for my various 6502-based computers/boards, in particular those based on the Ben Eater 6502 breadboard computer, I use OneROM (as well as [picoROM](https://github.com/wickerwaka/PicoROM)) in place of the AT28C256 EEPROM.

OneROM (and picoROM) can be re-programmed over USB-C inline and while powered up and running the system, saving the rigmarole of powering down the computer, removing the EEPROM, sticking it in the burner, burning it, and putting it back in the computer ...

OneROM has both visual, interactive, tools for creating firmware and ROM images, as well as a command line tool.  This folder contains too CLI-based commands for building and burning the required OneROM image:

## Building the OneROM Image
OneROM requires combining the `basic.bin` RAW (binary) ROM image file created by `make` with a OneROM firmware image and several parameters that tell OneROM how to handle the ROM.

`make_onerom.sh` builds this complete, flashable, image.

This is achieved by:

- Running `make` in the main project directory as usual (which will (re)create `bin/basic.bin`

- Running `./make_onerom.sh` from the `rom/` folder, which will create `ehbasic.rom`

## Burning the OneROM Image
To "burn" the OneROM firmware, settings and ROM image to the OneROM board, connect it via USB, and then from the `rom/` folder, run `./burn_onerom.sh`

---
# A Note on [E]EPROM Types
The Ben Eater 6502 is, in stock form, wired for AT28C256 EEPROMS.

OneROM can act as several different types of ROM/PROM/EPROM/EEPROM, including the AT28C256.

picoROM only behaves as an AT27C256 (or AT27XXX series) EPROM.

Since I use **both** picoROM and OneROM, I rewired my BE6502 to use the AT27C256 pinout (you can read about that [here](https://blog.imdlabs.com/eeproms-eeprom-emulators-27-vs-28-series-ics/); it is two simple, easily accessible, wiring changes).

As such, the OneROM tools I mention above build for an AT27C256 chip-type.  If you don't want to rewire your BE6502, then in `make_onerom.sh" change:

`type=27256` to `type=28256`
