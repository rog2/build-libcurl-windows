@echo off
setlocal EnableDelayedExpansion

@REM 
@REM Please make sure the following environment variables are set before calling this script:
@REM CURL_VERSION - Release version string.
@REM 

@if "%CURL_VERSION%"=="" (
    echo CURL_VERSION is not set, exit.
    exit /b 1
)

set CURL_ZIP=curl-%CURL_VERSION%.zip

REM Check if Visual Studio 2017 is installed
set VS2017DEVCMD="C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\VsDevCmd.bat"
if exist %VS2017DEVCMD% (
    set COMPILER_VER="2017"
    echo Using Visual Studio 2017 Community
    goto setup_env
)

echo No compiler : Microsoft Visual Studio 2017 Community is not installed.
goto end

:setup_env

:begin

REM Setup path to helper bin
set ROOT_DIR="%CD%"
set RM="%CD%\bin\unxutils\rm.exe"
set CP="%CD%\bin\unxutils\cp.exe"
set MKDIR="%CD%\bin\unxutils\mkdir.exe"

REM Housekeeping
%RM% -rf tmp_*
%RM% -rf third-party
%RM% -rf curl-*.zip
%RM% -rf build_*.txt

REM Download curl
echo Downloading curl %CURL_VERSION%
REM Force Invoke-WebRequest to use TLS 1.2
powershell -Command [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; ^
    Invoke-WebRequest -Uri "https://curl.haxx.se/download/%CURL_ZIP%" -OutFile %CURL_ZIP%

REM Extract downloaded zip file to tmp_libcurl
powershell -Command Expand-Archive -Path %CURL_ZIP% -DestinationPath tmp_libcurl

cd tmp_libcurl\curl-*\winbuild

if %COMPILER_VER% == "2017" (
    set VCVERSION = 15
    goto buildnow
)

:buildnow
REM Build!
echo %VS2017DEVCMD%

if [%1]==[-static] (
	set RTLIBCFG=static
	echo Using /MT instead of /MD
) 

REM We only need x64 build
call %VS2017DEVCMD% -arch=x64
cd /d "%ROOT_DIR%\tmp_libcurl\curl-*\winbuild"

echo Compiling static-debug-x64 version...
nmake /f Makefile.vc mode=static VC=%VCVERSION% DEBUG=yes MACHINE=x64

echo Compiling static-release-x64 version...
nmake /f Makefile.vc mode=static VC=%VCVERSION% DEBUG=no MACHINE=x64

REM Copy compiled .*lib file in lib-release folder to third-party\lib\static-debug folder
cd %ROOT_DIR%\tmp_libcurl\curl-*\builds\libcurl-vc-x64-debug-static-ipv6-sspi-winssl
%MKDIR% -p %ROOT_DIR%\third-party\libcurl\lib\static-debug-x64
%CP% lib\*.lib %ROOT_DIR%\third-party\libcurl\lib\static-debug-x64

REM Copy compiled .*lib files in lib-release folder to third-party\lib\static-release folder
cd %ROOT_DIR%\tmp_libcurl\curl-*\builds\libcurl-vc-x64-release-static-ipv6-sspi-winssl
%MKDIR% -p %ROOT_DIR%\third-party\libcurl\lib\static-release-x64
%CP% lib\*.lib %ROOT_DIR%\third-party\libcurl\lib\static-release-x64

REM Copy include folder to third-party folder
%CP% -rf include %ROOT_DIR%\third-party\libcurl

REM Cleanup temporary file/folders
cd %ROOT_DIR%
%RM% -rf tmp_*

:end
exit /b
