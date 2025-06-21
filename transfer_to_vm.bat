@echo off
echo ServerPulse Agent - File Transfer to Ubuntu VM
echo ===============================================
echo.

REM Check if parameters are provided
if "%~3"=="" (
    echo Usage: transfer_to_vm.bat ^<VM_IP^> ^<USERNAME^> ^<PASSWORD^>
    echo.
    echo Example: transfer_to_vm.bat 192.168.1.100 ubuntu mypassword
    echo.
    echo This script will:
    echo 1. Copy all agent files to your Ubuntu VM
    echo 2. Run the installation automatically
    echo 3. Show you the next steps
    echo.
    pause
    exit /b 1
)

set VM_IP=%1
set USERNAME=%2
set PASSWORD=%3

echo Target VM: %USERNAME%@%VM_IP%
echo.

REM Check if WinSCP is available
where winscp >nul 2>nul
if %errorlevel% neq 0 (
    echo WinSCP not found. Using built-in method...
    goto :BUILTIN_TRANSFER
)

echo Using WinSCP for file transfer...

REM Create temporary WinSCP script
echo open sftp://%USERNAME%:%PASSWORD%@%VM_IP% > winscp_script.txt
echo lcd %~dp0 >> winscp_script.txt
echo cd /tmp >> winscp_script.txt
echo put *.py >> winscp_script.txt
echo put *.sh >> winscp_script.txt
echo put *.yml >> winscp_script.txt
echo put requirements.txt >> winscp_script.txt
echo mkdir serverpulse-agent >> winscp_script.txt
echo cd serverpulse-agent >> winscp_script.txt
echo put -r collectors/ >> winscp_script.txt
echo put -r communication/ >> winscp_script.txt
echo put -r utils/ >> winscp_script.txt
echo call sudo chmod +x *.sh >> winscp_script.txt
echo call sudo ./quick_install.sh >> winscp_script.txt
echo exit >> winscp_script.txt

winscp /script=winscp_script.txt
del winscp_script.txt

goto :SUCCESS

:BUILTIN_TRANSFER
echo.
echo Manual transfer instructions:
echo.
echo 1. Copy these files to your Ubuntu VM using your preferred method:
echo    - All .py files
echo    - All .sh files (especially quick_install.sh)
echo    - All .yml files
echo    - requirements.txt
echo    - collectors/ folder
echo    - communication/ folder
echo    - utils/ folder
echo.
echo 2. On your Ubuntu VM, run:
echo    chmod +x quick_install.sh
echo    sudo ./quick_install.sh
echo.
pause
goto :END

:SUCCESS
echo.
echo ✅ Files transferred and installation started!
echo.
echo Next steps on your Ubuntu VM (%VM_IP%):
echo.
echo 1. Configure the agent:
echo    sudo nano /opt/serverpulse-agent/config.yml
echo.
echo 2. Update these settings:
echo    api_endpoint: "http://YOUR_SERVERPULSE_URL/api"
echo    server_id: "my-ubuntu-server"
echo    api_key: "your-api-key-if-needed"
echo.
echo 3. Start the agent:
echo    sudo systemctl start serverpulse-agent
echo.
echo 4. Test the installation:
echo    sudo python3 /opt/serverpulse-agent/test_installation.py
echo.
echo 5. Check the status:
echo    sudo systemctl status serverpulse-agent
echo.

:END
pause
