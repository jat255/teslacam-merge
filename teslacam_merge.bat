@echo off

set WINSCRIPTPATH=%0/../teslacam_merge.sh

REM Copy script to TEMP folder, since wsl has problems directly
REM accessing files on USB without doing some mounting business first
set REL_PATH=.\
set ABS_PATH=
pushd %REL_PATH%
set ABS_PATH=%CD%
set WINSCRIPTPATH=%ABS_PATH%\teslacam_merge.sh
popd
xcopy %WINSCRIPTPATH% %TEMP%\teslacam_merge.sh* /f /y
set WINSCRIPTPATH=%TEMP%\teslacam_merge.sh

wsl SCRIPT=$(wslpath -a "%WINSCRIPTPATH%"); echo $SCRIPT; $SCRIPT
echo Removing %WINSCRIPTPATH%
del "%WINSCRIPTPATH%" /f /q
pause