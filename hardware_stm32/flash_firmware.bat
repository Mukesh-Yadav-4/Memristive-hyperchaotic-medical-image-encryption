@echo off
setlocal enabledelayedexpansion

echo =======================================================
echo   Flashing M-4DCHS Firmware to STM32G474RE Nucleo
echo   Hardware-in-the-Loop Accelerator Stream
echo =======================================================

set "PROG=C:\ST\STM32CubeIDE_2.2.0\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.cubeprogrammer.win32_2.2.500.202603051304\tools\bin\STM32_Programmer_CLI.exe"
set "ELF_FILE=%~dp0m4dchs_stm32.elf"

if not exist "%PROG%" (
    echo [ERROR] STM32_Programmer_CLI.exe not found at:
    echo %PROG%
    pause
    exit /b 1
)

if not exist "%ELF_FILE%" (
    echo [ERROR] Firmware binary not found at:
    echo %ELF_FILE%
    echo Please run build_firmware.bat first!
    pause
    exit /b 1
)

echo [1/2] Connecting to ST-LINK and flashing firmware...
"%PROG%" -c port=SWD -w "%ELF_FILE%" -v -rst
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Flashing failed! Ensure the NUCLEO board is plugged in via USB and no serial monitor is holding COM10 open.
    pause
    exit /b 1
)

echo.
echo =======================================================
echo  SUCCESS: M-4DCHS Firmware Flashed to STM32G474RE!
echo  Ready for Hardware-in-the-Loop (HIL) Execution!
echo =======================================================
pause
