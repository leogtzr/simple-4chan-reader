# ===================== Configuración =====================
.DEFAULT_GOAL := help

# ===================== Targets =====================
.PHONY: build release clean test run help

help:                   # Muestra esta ayuda
	@echo "Available Commands"
	@echo "  make build     → Build"
	@echo "  make run       → Run the program and get the help"
	@echo "  make test      → Run tests"
	@echo "  make clean     → Clean assets"
	@echo "  make help      → Shows this help"

build:                  # Compila el binario
	zig build

clean:
	rm -rf zig-out/
	rm -rf zig-cache/

test:                   # Tests rápidos
	zig test

run:
	zig build run --

release:
	zig build -Doptimize=ReleaseSafe