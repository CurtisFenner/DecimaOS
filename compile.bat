

@echo off

set prompt=$$$G$S


lua clua32/clua32.lua c/kernel.c main kernel asm_compiled/kernel.asm
run.bat