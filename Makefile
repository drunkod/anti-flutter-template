.PHONY: check fmt

check:
	nix flake check

fmt:
	nix fmt
