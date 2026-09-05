# Makefile for julia-agent-tools

.PHONY: all dylib test clean

all: dylib

dylib:
	cd vendor/tree-sitter-julia && clang -O3 -shared -fPIC -arch x86_64 -arch arm64 -Isrc src/parser.c src/scanner.c -o tree-sitter-julia.dylib

test: dylib
	ast-grep test

clean:
	rm -f vendor/tree-sitter-julia/tree-sitter-julia.dylib
