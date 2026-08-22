CA65=ca65
LD65=ld65
CA65FLAGS=--cpu 65C02 --feature labels_without_colons

OBJS=obj/min_mon.o obj/wozmon.o obj/custom_commands.o

bin/basic.bin: $(OBJS) basic.cfg
	mkdir -p bin
	$(LD65) -o bin/basic.bin -C basic.cfg -m bin/basic.map $(OBJS)

obj/min_mon.o: min_mon.s basic.s
	mkdir -p obj
	$(CA65) $(CA65FLAGS) min_mon.s -o $@

obj/wozmon.o: wozmon.s
	mkdir -p obj
	$(CA65) $(CA65FLAGS) wozmon.s -o $@

obj/custom_commands.o: custom_commands.s
	mkdir -p obj
	$(CA65) $(CA65FLAGS) custom_commands.s -o $@

clean:
	rm -f $(OBJS) bin/basic.bin bin/basic.map

.PHONY: clean
