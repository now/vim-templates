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
       autoload \
       autoload/now \
       autoload/now/template \
       plugin \
       plugin/now

doc_FILES =

lib_FILES = \
	    autoload/now/template.vim \
	    autoload/now/template/attribute.vim \
	    autoload/now/template/entities.vim \
	    autoload/now/template/formatter.vim \
	    autoload/now/template/placeholders.vim \
	    autoload/now/template/updatableheaderlines.vim

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
