@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: 9router + CodeGraph MCP installer for OpenCode (Windows)
:: ============================================================================
:: If already installed, uninstalls cleanly first, then does a fresh install.
:: Sets 9router to start automatically at boot.
:: ============================================================================

echo.
echo ============================================================
echo  9router + CodeGraph MCP Installer for OpenCode
echo ============================================================
echo.

:: --- 0. Uninstall old versions first (reverse order: first unlink agents, then remove binaries) ------
echo [0/5] Checking for existing installations to clean up...

:: Unlink CodeGraph from agents before removing the binary
where codegraph >nul 2>&1
if not errorlevel 1 (
    echo        Unlinking CodeGraph from agents...
    codegraph uninstall --yes >nul 2>&1
)

:: Remove old boot entries first
schtasks /DELETE /TN "9router" /F >nul 2>&1

:: Then uninstall npm packages
npm list -g 9router >nul 2>&1
if not errorlevel 1 (
    echo        Uninstalling 9router...
    npm uninstall -g 9router >nul 2>&1
)

npm list -g @colbymchenry/codegraph >nul 2>&1
if not errorlevel 1 (
    echo        Uninstalling @colbymchenry/codegraph...
    npm uninstall -g @colbymchenry/codegraph >nul 2>&1
)

echo        Cleaning npm cache...
call npm cache clean --force >nul 2>&1

echo        Cleanup done.

:: --- 1. Check Node.js / npm -------------------------------------------------
echo.
echo [1/5] Checking Node.js and npm...
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js not found. Install from https://nodejs.org/
    pause
    exit /b 1
)
npm --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: npm not found.
    pause
    exit /b 1
)
echo        Node: & node --version
echo        npm:  & npm --version

:: --- 2. Install 9router -----------------------------------------------------
echo.
echo [2/5] Installing 9router...
npm install -g 9router
if errorlevel 1 (
    echo ERROR: Failed to install 9router.
    pause
    exit /b 1
)
echo        9router installed.

:: --- 3. Install CodeGraph ---------------------------------------------------
echo.
echo [3/5] Installing CodeGraph (@colbymchenry/codegraph)...
npm install -g @colbymchenry/codegraph
if errorlevel 1 (
    echo ERROR: Failed to install CodeGraph.
    pause
    exit /b 1
)
echo        CodeGraph installed.
echo.
echo        Wiring CodeGraph MCP into OpenCode...
for /f "tokens=*" %%i in ('npm config get prefix') do set "NPM_PREFIX=%%i"
if exist "!NPM_PREFIX!\codegraph.cmd" (
    "!NPM_PREFIX!\codegraph.cmd" install --yes
) else if exist "!NPM_PREFIX!\codegraph" (
    "!NPM_PREFIX!\codegraph" install --yes
) else (
    echo        WARNING: codegraph binary not found in npm prefix (!NPM_PREFIX!).
    echo        Try running: npm install -g @colbymchenry/codegraph
)

:: --- 4. Set 9router to start on boot ----------------------------------------
echo.
echo [4/5] Setting 9router to auto-start on boot...

:: Find the actual 9router.cmd path from npm
for /f "tokens=*" %%i in ('where 9router 2^>nul') do set "NINE_PATH=%%i"
if defined NINE_PATH (
    schtasks /CREATE /SC ONLOGON /TN "9router" /TR "!NINE_PATH! -t --host 127.0.0.1" /DELAY 0005:00 /F >nul 2>&1
) else (
    schtasks /CREATE /SC ONLOGON /TN "9router" /TR "%APPDATA%\npm\9router.cmd -t --host 127.0.0.1" /DELAY 0005:00 /F >nul 2>&1
)
if errorlevel 1 (
    echo        WARNING: Could not create scheduled task. Run as Administrator for auto-start.
    echo        To set it manually: run '9router' whenever you need it.
) else (
    echo        9router will auto-start 5 minutes after login.
)

:: --- Done -------------------------------------------------------------------
echo.
echo [5/5] Done!
echo.
echo ============================================================
echo  Installation complete!
echo ============================================================
echo.
echo  What was done:
echo    - Cleaned up any previous install
echo    - 9router installed (global npm)
echo    - CodeGraph installed (global npm)
echo    - CodeGraph MCP wired into OpenCode
echo    - 9router scheduled to auto-start at login
echo.
echo  Next steps:
echo    1. Start 9router:         9router
echo    2. Configure Kimi provider at http://localhost:20128
echo    3. Set provider API key in OpenCode config manually
echo    4. Restart OpenCode
echo    5. Index your project:    codegraph init .
echo.

endlocal
pause
