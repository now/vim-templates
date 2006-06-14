# contents: Vim Templates Makefile.
#
# Copyright © 2006 Nikolai Weibull <now@bitwi.se>

uname_O := $(shell uname -o 2>/dev/null || echo nothing)

DESTDIR = $(HOME)/.vim

INSTALL = install

ifeq ($(uname_O),Cygwin)
	DESTDIR = $(HOME)/vimfiles
endif

DIRS = \
       lib \
       lib/now \
       lib/now/templates \
       plugin \
       plugin/now

doc_FILES =

lib_FILES = \
	    lib/now.vim \
	    lib/now/templates.vim \
	    lib/now/templates/attribute.vim \
	    lib/now/templates/entities.vim \
	    lib/now/templates/formatter.vim \
	    lib/now/templates/template.vim \
	    lib/now/templates/updatableheaderlines.vim

plugin_FILES = \
	       plugin/now/templates.vim

FILES = \
	$(doc_FILES) \
	$(lib_FILES) \
	$(plugin_FILES)

dest_DIRS = $(addprefix $(DESTDIR)/,$(DIRS))

dest_FILES = $(addprefix $(DESTDIR)/,$(FILES))

-include config.mk

.PHONY: all install

all:
	@echo Please run “make install” to install files.

install: $(dest_DIRS) $(dest_FILES)

$(DESTDIR)/%: %
	$(INSTALL) --mode=644 $< $@

$(dest_DIRS):
	$(INSTALL) --directory --mode=755 $@
