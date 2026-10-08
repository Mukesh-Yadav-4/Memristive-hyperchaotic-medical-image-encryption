@echo off
setlocal enabledelayedexpansion

echo =======================================================
echo   Compiling M-4DCHS Firmware for STM32G474RE
echo   Architecture: ARM Cortex-M4 + Hardware FPU
echo =======================================================

set "TOOL_DIR=C:\ST\STM32CubeIDE_2.2.0\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.14.3.rel1.win32_1.0.100.202602081740\tools\bin"
set "CC=%TOOL_DIR%\arm-none-eabi-gcc.exe"
set "OBJCOPY=%TOOL_DIR%\arm-none-eabi-objcopy.exe"
set "SIZE=%TOOL_DIR%\arm-none-eabi-size.exe"

set "PROJ_DIR=%~dp0"
set "SRC_DIR=%PROJ_DIR%Src"
set "STARTUP=%PROJ_DIR%Startup\startup_stm32g474retx.s"
set "LINKER=%PROJ_DIR%STM32G474RETX_FLASH.ld"
set "OUT_ELF=%PROJ_DIR%m4dchs_stm32.elf"
set "OUT_BIN=%PROJ_DIR%m4dchs_stm32.bin"

if not exist "%CC%" (
    echo [ERROR] arm-none-eabi-gcc not found at: %CC%
    exit /b 1
)

echo [1/3] Compiling C and Assembly source files...
"%CC%" -mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb ^
    -O2 -Wall -fdata-sections -ffunction-sections ^
    -I"%PROJ_DIR%Inc" ^
    -T"%LINKER%" ^
    -Wl,-Map="%PROJ_DIR%m4dchs_stm32.map" -Wl,--gc-sections -static ^
    --specs=nano.specs --specs=nosys.specs ^
    "%SRC_DIR%\main.c" "%SRC_DIR%\syscalls.c" "%SRC_DIR%\sysmem.c" "%STARTUP%" ^
    -lm -lc -o "%OUT_ELF%"

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Compilation failed!
    exit /b 1
)

echo [2/3] Generating raw binary (%OUT_BIN%)...
"%OBJCOPY%" -O binary "%OUT_ELF%" "%OUT_BIN%"

echo [3/3] Analyzing firmware memory consumption...
"%SIZE%" "%OUT_ELF%"

echo.
echo =======================================================
echo  SUCCESS: M-4DCHS ARM Cortex-M4 Firmware Built!
echo =======================================================
