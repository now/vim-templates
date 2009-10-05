VIMBALL = templates.vba

FILES = \
	autoload/now/template.vim \
	autoload/now/template/attribute.vim \
	autoload/now/template/entities.vim \
	autoload/now/template/formatter.vim \
	autoload/now/template/placeholders.vim \
	autoload/now/template/updatableheaderlines.vim \
	plugin/now/templates.vim

.PHONY: build install package

build: $(VIMBALL)

install: build
	ex -N --cmd 'set eventignore=all' -c 'so %' -c 'quit!' $(VIMBALL)

package: $(VIMBALL).gz

%.vba: Manifest $(FILES)
	ex -N -c '%MkVimball! $@ .' -c 'quit!' $<

%.gz: %
	gzip -c $< > $@

Manifest: Makefile
	for f in $(FILES); do echo $$f; done > $@
