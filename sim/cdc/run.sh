#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

RTL="rtl/cdc/async_fifo.sv"
DIRECTED_TB="sim/cdc/tb_async_fifo.sv"
RANDOM_TB="sim/cdc/tb_async_fifo_random.sv"

iverilog -g2012 -s tb_async_fifo \
  -o "$BUILD_DIR/fifo_slow_fast" "$RTL" "$DIRECTED_TB"
vvp "$BUILD_DIR/fifo_slow_fast"

iverilog -g2012 -s tb_async_fifo \
  -Ptb_async_fifo.WR_HALF_PERIOD=7.143 \
  -Ptb_async_fifo.RD_HALF_PERIOD=71.429 \
  -o "$BUILD_DIR/fifo_fast_slow" "$RTL" "$DIRECTED_TB"
vvp "$BUILD_DIR/fifo_fast_slow"

iverilog -g2012 -s tb_async_fifo_random \
  -o "$BUILD_DIR/fifo_random_slow_fast" "$RTL" "$RANDOM_TB"
vvp "$BUILD_DIR/fifo_random_slow_fast"

iverilog -g2012 -s tb_async_fifo_random \
  -Ptb_async_fifo_random.WR_HALF_PERIOD=7.143 \
  -Ptb_async_fifo_random.RD_HALF_PERIOD=71.429 \
  -o "$BUILD_DIR/fifo_random_fast_slow" "$RTL" "$RANDOM_TB"
vvp "$BUILD_DIR/fifo_random_fast_slow"

verilator --lint-only -Wall -Wno-fatal "$RTL"
yosys -p "read_verilog -sv $RTL; hierarchy -check -top async_fifo; proc; memory; opt; check; stat"
