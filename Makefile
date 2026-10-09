# Makefile for julia-agent-tools

.PHONY: all dylib test test-ast test-ctags test-julia install-ctags clean

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    CC := clang
    DYLIB_FLAGS := -arch x86_64 -arch arm64
else
    # make predefines CC=cc, so `?=` never fires; only override make's own default
    ifeq ($(origin CC),default)
        CC := gcc
    endif
    DYLIB_FLAGS :=
endif


all: dylib

dylib:
	cd vendor/tree-sitter-julia && $(CC) -O3 -shared -fPIC $(DYLIB_FLAGS) -Isrc src/parser.c src/scanner.c -o tree-sitter-julia.dylib


test: test-ast test-ctags test-julia

# ast-grep 0.50+ refuses native custom-language libraries unless told otherwise; older
# versions do not know the option. Detect it once.
SG_POLICY := $(shell ast-grep --help 2>/dev/null | grep -q -- --custom-languages && echo --custom-languages allow)

test-ast: dylib
	ast-grep test $(SG_POLICY) -c sgconfig.yml

test-ctags:
	./test/test_ctags.sh

test-julia:
	julia --project=. -e 'using Pkg; Pkg.test()'

test-corpus: dylib
	./scripts/test_corpus.sh


install-ctags:
	mkdir -p $(HOME)/.ctags.d
	cp ctags.d/julia.ctags $(HOME)/.ctags.d/julia.ctags
	@echo "Installed julia.ctags to $(HOME)/.ctags.d/julia.ctags"

clean:
	rm -f vendor/tree-sitter-julia/tree-sitter-julia.dylib tags
