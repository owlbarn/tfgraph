OPAM_LIB := $(shell opam config var lib 2>/dev/null)
OPAM_STUBS := $(shell opam config var stublibs 2>/dev/null)

.PHONY: all
all: build

.PHONY: depend depends
depend depends:
	dune external-lib-deps --missing @install @runtest

.PHONY: build
build: depends
	dune build @install

.PHONY: test
test: depends
	dune runtest -j 1 --no-buffer -p owl

.PHONY: clean
clean:
	dune clean

.PHONY: install
install: build
	dune install

.PHONY: uninstall
uninstall:
	dune uninstall

.PHONY: doc
doc:
	opam install -y odoc
	dune build @doc

.PHONY: push
push:
	git commit -am "coding ..." && \
	git push origin `git branch | grep \* | cut -d ' ' -f2`


PKGS=owl-tensorflow
.PHONY: release
release:
	make install # as package distrib steps rely on owl-base etc
	opam install --yes dune-release
	dune-release tag
	dune-release distrib
	dune-release publish

	dune-release opam pkg -p owl-tensorflow
	dune-release opam submit -p $(PKGS)
