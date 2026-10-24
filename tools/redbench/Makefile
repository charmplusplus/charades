# CHARMC: the Reconverse charmc (e.g. $WORK/charm-pads-exp/reconverse-linux-x86_64/bin/charmc)
CHARMC ?= charmc
redbench: redbench.C redbench.decl.h
	$(CHARMC) -O3 -std=c++17 -language charm++ -o $@ redbench.C
redbench.decl.h: redbench.ci
	$(CHARMC) redbench.ci
clean:
	rm -f redbench *.decl.h *.def.h *.o
