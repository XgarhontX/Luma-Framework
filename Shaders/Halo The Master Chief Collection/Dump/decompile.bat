@echo off

:: folder path
set "folder=%~dp0"

echo Scanning %folder% for .cso files...

FOR /f %%G IN ('dir /b /o:n "%folder%\*.cso"') DO (
    CALL :decompile "%%G"
)

echo.
echo Done processing all .cso files.
pause
GOTO :eof

:decompile
SETLOCAL
SET "file=%~1"
SET "csoFile=%folder%\%file%"
SET "asmFile=%folder%\%file:.cso=.asm%"
SET "shdrFile=%folder%\%file:.cso=.shdr%"

echo.
echo ================================================
echo Decompiling %file%
echo ================================================

:: Step 1: .cso → .asm
cmd_Decompiler.exe -d "%csoFile%"

IF NOT EXIST "%asmFile%" (
    echo ERROR: .asm not created for %file%, skipping...
    GOTO :eof
)

:: Step 2: .asm → .shdr
cmd_Decompiler.exe -a "%asmFile%"

IF NOT EXIST "%shdrFile%" (
    echo ERROR: .shdr not created for %file%, skipping...
    GOTO :eof
)

:: Step 3: .shdr → .hlsl
cmd_Decompiler.exe -D "%shdrFile%"

:: Step 4: Delete Excess
::IF EXIST "%csoFile%" del "%csoFile%"
IF EXIST "%asmFile%" del "%asmFile%"
IF EXIST "%shdrFile%" del "%shdrFile%"


ENDLOCAL
GOTO :eof