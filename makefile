##
##  LibreSignage makefile
##

NPMBIN := $(shell ./build/scripts/npmbin.sh)
ROOT := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

SASS_IPATHS := $(ROOT) $(ROOT)src/common/css
SASSFLAGS := --sourcemap=none --no-cache

VERBOSE=y

# Directories.
DIRS := $(shell find src \
	\( -type d -path 'src/node_modules' -prune \) \
	-o \( -type d -print \) \
)

# Production libraries.
LIBS := $(filter-out \
	$(shell echo "$(ROOT)"|sed 's:/$$::g'), \
	$(shell npm ls --prod --parseable|sed 's/\n/ /g') \
)

# Non-compiled sources.
SRC_NO_COMPILE := $(shell find src \
	\( -type f -path 'src/node_modules/*' -prune \) \
	-o \( -type f -path 'src/api/endpoint/*' -prune \) \
	-o \( \
		-type f ! -name '*.js' \
		-a -type f ! -name '*.scss' \
		-a -type f ! -name '*.rst' \
		-a -type f ! -name 'config.php' -print \
	\) \
)

# RST sources.
SRC_RST := $(shell find src \
	\( -type f -path 'src/node_modules/*' -prune \) \
	-o -type f -name '*.rst' -print \
) README.rst

# SCSS sources.
SRC_SCSS := $(shell find src \
	\( -type f -path 'src/node_modules/*' -prune \) \
	-o -type f -name '*.scss' -print \
)

# JavaScript sources.
SRC_JS := $(shell find src \
	\( -type f -path 'src/node_modules/*' -prune \) \
	-o \( -type f -name 'main.js' -print \) \
)

# API endpoint sources.
SRC_ENDPOINT := $(shell find src/api/endpoint \
	\( -type f -path 'src/node_modules/*' -prune \) \
	-o \( -type f -name '*.php' -print \) \
)

status = \
	if [ "$(VERBOSE)" = "y" ]; then \
		echo "$(1): $(2) >> $(3)"|tr -s ' '|sed 's/^ *$///g'; \
	fi

ifndef INST
INST := ""
endif

ifndef NOHTMLDOCS
NOHTMLDOCS := N
endif

ifeq ($(NOHTMLDOCS),$(filter $(NOHTMLDOCS),y Y))
$(info [INFO] Won't generate HTML documentation.)
endif

.PHONY: initchk configure dirs server js css api \
		config libs docs htmldocs install utest \
		clean realclean LOC
.ONESHELL:

all:: dirs server docs htmldocs js css api config libs; @:

dirs:: initchk $(subst src,dist,$(DIRS)); @:
server:: initchk dirs $(subst src,dist,$(SRC_NO_COMPILE)); @:
js:: initchk dirs $(subst src,dist,$(SRC_JS)); @:
api:: initchk dirs $(subst src,dist,$(SRC_ENDPOINT)); @:
config:: initchk dirs dist/common/php/config.php; @:
libs:: initchk dirs dist/libs; @:
docs:: initchk dirs $(addprefix dist/doc/rst/,$(notdir $(SRC_RST))); @:
htmldocs:: initchk dirs $(addprefix dist/doc/html/,$(notdir $(SRC_RST:.rst=.html)))
css:: initchk dirs $(subst src,dist,$(SRC_SCSS:.scss=.css)); @:
libs:: initchk dirs $(subst $(ROOT)node_modules/,dist/libs/,$(LIBS)); @:

# Create directory structure in 'dist/'.
$(subst src,dist,$(DIRS)):: dist%: src%
	@:
	mkdir -p $@;

# Copy over non-compiled, non-PHP sources.
$(filter-out %.php,$(subst src,dist,$(SRC_NO_COMPILE))):: dist%: src%
	@:
	$(call status,cp,$<,$@);
	cp -p $< $@;

# Copy over normal PHP files and check the PHP syntax.
$(filter %.php,$(subst src,dist,$(SRC_NO_COMPILE))):: dist%: src%
	@:
	php -l $< > /dev/null;

	$(call status,cp,$<,$@);
	cp -p $< $@;

# Copy API endpoint PHP files and generate corresponding docs.
$(subst src,dist,$(SRC_ENDPOINT)):: dist%: src%
	@:
	php -l $< > /dev/null;

	$(call status,cp,$<,$@);
	cp -p $< $@;

	if [ ! "$$NOHTMLDOCS" = "y" ] && [ ! "$$NOHTMLDOCS" = "Y" ]; then
		# Generate reStructuredText documentation.
		mkdir -p dist/doc/rst;
		mkdir -p dist/doc/html;
		$(call status,\
			gendoc.sh,\
			<generated>,\
			dist/doc/rst/$(notdir $(@:.php=.rst))\
		);
		./build/scripts/gendoc.sh $(INST) $@ dist/doc/rst/

		# Compile rst docs into HTML.
		$(call status,\
			pandoc,\
			dist/doc/rst/$(notdir $(@:.php=.rst)),\
			dist/doc/html/$(notdir $(@:.php=.html))\
		)
		pandoc -f rst -t html \
			-o dist/doc/html/$(notdir $(@:.php=.html)) \
			dist/doc/rst/$(notdir $(@:.php=.rst))
	fi

# Generate the API endpoint documentation index.
dist/doc/rst/api_index.rst:: $(SRC_ENDPOINT)
	@:
	$(call status,makefile,<generated>,$@);

	@. build/scripts/conf.sh
	echo "LibreSignage API documentation (Ver: $$ICONF_API_VER)" > $@;
	echo '########################################################' >> $@;
	echo '' >> $@;
	echo "This document was automatically generated by the"\
		"LibreSignage build system on `date`." >> $@;
	echo '' >> $@;
	for f in $(SRC_ENDPOINT); do
		echo "\``basename $$f` </doc?doc=`basename -s '.php' $$f`>\`_" >> $@;
		echo '' >> $@;
	done

	# Compile into HTML.
	if [ ! "$$NOHTMLDOCS" = "y" ] && [ ! "$$NOHTMLDOCS" = "Y" ]; then
		$(call status,pandoc,$(subst /rst/,/html/,$($:.rst=.html)),$@);
		pandoc -f rst -t html -o $(subst /rst/,/html/,$(@:.rst=.html)) $@;
	fi

# Copy and prepare 'config.php'.
dist/common/php/config.php:: src/common/php/config.php
	@:
	$(call status,cp,$<,$@);
	cp -p $< $@;
	$(call status,prep.sh,<inplace>,$@);
	./build/scripts/prep.sh $(INST) $@
	php -l $@ > /dev/null;

# Generate JavaScript deps.
dist/%/main.js.dep: src/%/main.js
	@:
	$(call status,deps-js,$<,$@);
	echo "all:: `$(NPMBIN)/browserify --list $<|tr '\n' ' '`" > $@;
	echo "\t@$(NPMBIN)/browserify"\
		"$(ROOT)$<"\
		"-o $(ROOT)$(subst src,dist,$<)" >> $@;

# Compile JavaScript sources.
dist/%/main.js: dist/%/main.js.dep src/%/main.js
	@:
	$(call status,browserify,$(word 2,$^),$@);
	$(MAKE) --no-print-directory -C $(dir $<) -f $(notdir $<);

# Copy over README.rst.
dist/doc/rst/README.rst:: README.rst
	@:
	$(call status,cp,$<,$@);
	cp -p $< $@;

# Copy over RST sources.
dist/doc/rst/%.rst:: src/doc/rst/%.rst
	@:
	$(call status,cp,$<,$@);
	cp -p $< $@;

# Compile RST sources into HTML.
dist/doc/html/%.html:: src/doc/rst/%.rst
	@:
	if [ ! "$$NOHTMLDOCS" = "y" ] && [ ! "$$NOHTMLDOCS" = "Y" ]; then
		mkdir -p dist/doc/html;
		$(call status,pandoc,$<,$@);
		pandoc -o $@ -f rst -t html $<;
	fi

# Compile README.rst
dist/doc/html/README.html:: README.rst
	@:
	if [ ! "$$NOHTMLDOCS" = "y" ] && [ ! "$$NOHTMLDOCS" = "Y" ]; then
		mkdir -p dist/doc/html;
		$(call status,pandoc,$<,$@);
		pandoc -o $@ -f rst -t html $<;
	fi

# Generate SCSS deps.
dist/%.scss.dep: src/%.scss
	@:
	# Don't create deps for partials.
	if [ ! "`basename '$(<)' | cut -c 1`" = "_" ]; then
		$(call status,deps-scss,$<,$@);
		echo "all:: `./build/scripts/sassdep.py -l $< $(SASS_IPATHS)`" > $@;

		# Compile with sass.
		echo "\t@sass"\
			"$(addprefix -I,$(SASS_IPATHS))"\
			"$(SASSFLAGS)"\
			"$(ROOT)$<"\
			"$(ROOT)$(subst src,dist,$(<:.scss=.css));" >> $@;

		# Process with postcss.
		echo "\t@$(NPMBIN)/postcss"\
			"$(ROOT)$(subst src,dist,$(<:.scss=.css))"\
			"--config $(ROOT)postcss.config.js"\
			"--replace"\
			"--no-map;" >> $@;
	fi

# Compile Sass sources.
dist/%.css: dist/%.scss.dep src/%.scss
	@:
	# Don't compile partials.
	if [ ! "`basename '$(word 2,$^)' | cut -c 1`" = "_" ]; then
		$(call status,compile-scss,$(word 2,$^),$@);
		$(MAKE) --no-print-directory -C $(dir $<) -f $(notdir $<);
	else
		$(call status,skip,$(word 2,$^),$@);
	fi

# Copy production node modules to 'dist/libs/'.
dist/libs/%:: node_modules/%
	@:
	mkdir -p $@;
	$(call status,cp,$<,$@);
	cp -Rp $</* $@;

install:; @./build/scripts/install.sh $(INST)

utest:; @./utests/api/main.py

clean:
	rm -rf dist;
	rm -rf `find . -type d -name '__pycache__'`;
	rm -rf `find . -type d -name '.sass-cache'`;
	rm -f *.log;

realclean:
	rm -f build/*.iconf;
	rm -rf build/link;
	rm -rf node_modules;
	rm -f package-lock.json

# Count the lines of code in LibreSignage.
LOC:
	@:
	echo 'Lines Of Code: ';
	wc -l `find . \
		\( \
			-path "./dist/*" -o \
			-path "./utests/api/.mypy_cache/*" -o \
			-path "./node_modules/*" \
		\) -prune \
		-o -name "*.py" -print \
		-o -name "*.php" -print \
		-o -name "*.js" -print \
		-o -name "*.html" -print \
		-o -name "*.css" -print \
		-o -name "*.scss" -print \
		-o -name "*.sh" -print \
		-o ! -name 'package-lock.json' -name "*.json" -print \
		-o -name "*.py" -print`

LOD:
	@:
	echo '[INFO] Make sure your 'dist/' is up to date!';
	echo '[INFO] Lines Of Documentation: ';
	wc -l `find dist -type f -name '*.rst'`

configure:
	@:
	./build/scripts/configure.sh

initchk:
	@:
	./build/scripts/ldiconf.sh $(INST);

%:
	@:
	echo "[INFO]: Ignore $@";
