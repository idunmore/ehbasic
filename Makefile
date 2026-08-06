CA65=ca65
LD65=ld65

basic.bin: min_mon.o
	$(LD65) -o bin/basic.bin \
		-C basic.cfg \
		obj/min_mon.o

min_mon.o: min_mon.s basic.s
	mkdir -p bin
	mkdir -p obj
	$(CA65) --cpu 65C02 --feature labels_without_colons min_mon.s -o obj/min_mon.o

clean:
	rm -f obj/min_mon.o bin/basic.bin
