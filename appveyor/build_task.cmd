@echo off
setlocal enableextensions enabledelayedexpansion

	cd /D %APPVEYOR_BUILD_FOLDER%
	if %errorlevel% neq 0 exit /b 3

	set STABILITY=staging
	set DEPS_DIR=%PHP_BUILD_CACHE_BASE_DIR%\deps-%PHP_REL%-%PHP_SDK_VC%-%PHP_SDK_ARCH%
	rem SDK is cached, deps info is cached as well
	echo Updating dependencies in %DEPS_DIR%
	cmd /c phpsdk_deps --update --no-backup --branch %PHP_REL% --stability %STABILITY% --deps %DEPS_DIR% --crt %PHP_BUILD_CRT%
	if %errorlevel% neq 0 exit /b 3

	rem Something went wrong, most likely when concurrent builds were to fetch deps
	rem updates. It might be, that some locking mechanism is needed.
	if not exist "%DEPS_DIR%" (
		cmd /c phpsdk_deps --update --force --no-backup --branch %PHP_REL% --stability %STABILITY% --deps %DEPS_DIR% --crt %PHP_BUILD_CRT%
	)
	if %errorlevel% neq 0 exit /b 3

	for %%z in (%ZTS_STATES%) do (
		set ZTS_STATE=%%z
		if "!ZTS_STATE!"=="enable" set ZTS_SHORT=ts
		if "!ZTS_STATE!"=="disable" set ZTS_SHORT=nts

		cd /d C:\projects\php-src

		cmd /c buildconf.bat --force

		if %errorlevel% neq 0 exit /b 3

		cmd /c configure.bat --disable-all --with-mp=auto --enable-cli --!ZTS_STATE!-zts --enable-embed --enable-object-out-dir=%PHP_BUILD_OBJ_DIR% --with-config-file-scan-dir=%APPVEYOR_BUILD_FOLDER%\build\modules.d --with-prefix=%APPVEYOR_BUILD_FOLDER%\build --with-php-build=%DEPS_DIR%

		if %errorlevel% neq 0 exit /b 3

		nmake /NOLOGO

		if %errorlevel% neq 0 exit /b 3

		nmake install

		if %errorlevel% neq 0 exit /b 3

		cd /d %APPVEYOR_BUILD_FOLDER%

        MSBuild.exe %APPVEYOR_BUILD_FOLDER%\src\embeder.sln /p:Configuration="Debug console" /p:Platform="Win32"

        IF NOT EXIST "%APPVEYOR_BUILD_FOLDER%\build\php.exe" echo Error, PHP not found. && exit /b 1

        rem%APPVEYOR_BUILD_FOLDER%\build\php.exe %APPVEYOR_BUILD_FOLDER%\php\embeder2.php new embeder2
        rem %APPVEYOR_BUILD_FOLDER%\build\php.exe %APPVEYOR_BUILD_FOLDER%\php\embeder2.php main embeder2 %APPVEYOR_BUILD_FOLDER%\php\embeder2.php
        rem %APPVEYOR_BUILD_FOLDER%\build\php.exe %APPVEYOR_BUILD_FOLDER%\php\embeder2.php add embeder2 %APPVEYOR_BUILD_FOLDER%\out\console.exe %APPVEYOR_BUILD_FOLDER%\out\console.exe

		rem xcopy %APPVEYOR_BUILD_FOLDER% %APPVEYOR_BUILD_FOLDER%\embeder\ /y /f

		rem Compiled PHP embedded
		rem 7z a embedder.zip C:\obj\Release_TS\*

		rem embed.exe that was built
		7z a embedder.zip C:\projects\embedder\*

		appveyor PushArtifact embedder.zip -FileName embedder.zip
	)
endlocal
