#

# run GHDL
GHDLRUN = /usr/bin/ghdl
GHDLOPT = --ieee=synopsys
GHDLA = $(GHDLRUN) -a $(GHDLOPT)
GHDLE = $(GHDLRUN) -e $(GHDLOPT)
GHDLR = $(GHDLRUN) -r $(GHDLOPT)

WORK = counter_tb.vhd ../src/counter.vhd

DAQTIM = 1us

define analyze_VHDL
  echo $(GHDLA) $(1) $(2);
  $(GHDLA) $(1) $(2);
endef

all: analyze.ready counter_tb.ghw

run:
	$(GHDLE) daq_tb
	$(GHDLR) daq_tb --stop-time=$(DAQTIM) --wave=daq_tb.ghw

analyze.ready: $(WORK) Makefile
	rm -f *.cf
	$(foreach vf,$(WORK), $(call analyze_VHDL, --work=work, $(vf)))
	touch analyze.ready

clean:
	rm -f *~ *.cf *.vcd *.ghw *.db *.ready counter_tb

counter_tb.ghw: analyze.ready Makefile
	$(GHDLE) counter_tb
	$(GHDLR) counter_tb --stop-time=$(DAQTIM) --wave=counter_tb.ghw
