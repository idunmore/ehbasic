CA65=ca65
LD65=ld65
CA65FLAGS=--cpu 65C02 --feature labels_without_colons

# optional build time features, these two off unless asked for. see min_mon.s
#
#   make SENTINEL=n   build the program chain sentinel in, armed at n headers
#                     per statement on reset. 0 builds it in but leaves it
#                     disarmed, and POKE 236,n arms it at any time either way
#   make DEBUG=1      build the block watch, the 8009R bus stress test and the
#                     page zero dump in
#
# and one that is on unless you turn it off
#
#   make LCD=0        leave the HD44780 LCD extensions out entirely. do this on
#                     a board with no LCD on VIA port B, because LCDINIT polls
#                     the display's busy flag at reset and a floating input
#                     never clears it, which hangs the machine before the
#                     [C]old/[W]arm prompt
#
# examples
#   make                        the stock ROM, LCD in, no debug aids
#   make LCD=0                  no LCD, for a board without one fitted
#   make SENTINEL=1             sentinel in, armed at 1
#   make SENTINEL=1 DEBUG=1     everything

ifdef SENTINEL
CA65FLAGS += -D SENTINEL_INIT=$(SENTINEL)
endif
ifdef DEBUG
CA65FLAGS += -D DEBUG_TOOLS=1
endif

# unlike the two above this one is always passed, because it defaults to on.
# min_mon.s and custom_commands.s both fall back to 1 if it is missing, so a
# hand run of ca65 without it still gets the same ROM a plain "make" does
LCD ?= 1
CA65FLAGS += -D LCD_ENABLE=$(LCD)

OBJS=obj/min_mon.o obj/wozmon.o obj/custom_commands.o

# the options above change what gets assembled, so everything has to be rebuilt
# whenever they change. keep a stamp of the flags and throw the objects away
# when it moves, which saves having to remember a "make clean". deleting rather
# than depending on the stamp because make here compares mtimes to the second,
# and two builds can easily land in the same one
FLAGS_STAMP=obj/.ca65flags
$(shell mkdir -p obj; echo '$(CA65FLAGS)' | cmp -s - $(FLAGS_STAMP) 2>/dev/null \
        || { echo '$(CA65FLAGS)' > $(FLAGS_STAMP); rm -f $(OBJS) bin/basic.bin; })

bin/basic.bin: $(OBJS) basic.cfg
	@mkdir -p bin
	$(LD65) -o bin/basic.bin -C basic.cfg -m bin/basic.map $(OBJS)

obj/min_mon.o: min_mon.s basic.s
	@mkdir -p obj
	$(CA65) $(CA65FLAGS) min_mon.s -o $@

obj/wozmon.o: wozmon.s
	@mkdir -p obj
	$(CA65) $(CA65FLAGS) wozmon.s -o $@

obj/custom_commands.o: custom_commands.s
	@mkdir -p obj
	$(CA65) $(CA65FLAGS) custom_commands.s -o $@

clean:
	rm -f $(OBJS) $(FLAGS_STAMP) bin/basic.bin bin/basic.map

.PHONY: clean
