# Makefile for julia-agent-tools

.PHONY: all dylib test test-ast test-ctags test-julia install-ctags clean

all: dylib

dylib:
	cd vendor/tree-sitter-julia && clang -O3 -shared -fPIC -arch x86_64 -arch arm64 -Isrc src/parser.c src/scanner.c -o tree-sitter-julia.dylib

test: test-ast test-ctags test-julia

test-ast: dylib
	ast-grep test -c sgconfig.yml

test-ctags:
	./test/test_ctags.sh

test-julia:
	julia --project=. -e 'using Pkg; Pkg.test()'

install-ctags:
	mkdir -p $(HOME)/.ctags.d
	cp ctags.d/julia.ctags $(HOME)/.ctags.d/julia.ctags
	@echo "Installed julia.ctags to $(HOME)/.ctags.d/julia.ctags"

clean:
	rm -f vendor/tree-sitter-julia/tree-sitter-julia.dylib tags
