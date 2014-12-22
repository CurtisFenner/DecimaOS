

@echo off

set prompt=$$$G$S


lua clua32/clua32.lua kernel.c main kernel asm/kernel.asm
run.bat