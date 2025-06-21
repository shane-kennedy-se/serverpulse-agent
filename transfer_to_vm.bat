@echo off
REM Windows batch script to transfer agent to Linux VM

echo ServerPulse Agent - Transfer to Linux VM
echo ==========================================

REM Get VM connection details
set /p VM_IP="Enter Linux VM IP address: "
set /p VM_USER="Enter Linux VM username: "

echo.
echo Creating deployment package...
tar -czf serverpulse-agent.tar.gz *

echo.
echo Transferring to Linux VM...
scp serverpulse-agent.tar.gz %VM_USER%@%VM_IP%:/tmp/

echo.
echo Connecting to VM for installation...
echo.

REM Create SSH commands file
echo cd /tmp > ssh_commands.txt
echo tar -xzf serverpulse-agent.tar.gz >> ssh_commands.txt
echo cd serverpulse-agent >> ssh_commands.txt
echo chmod +x *.sh >> ssh_commands.txt
echo echo "Files extracted. Run: ./setup_linux.sh" >> ssh_commands.txt

REM Execute commands on VM
ssh %VM_USER%@%VM_IP% < ssh_commands.txt

echo.
echo Files transferred! Now connect to your VM and run:
echo   ssh %VM_USER%@%VM_IP%
echo   cd /tmp/serverpulse-agent
echo   ./setup_linux.sh

REM Cleanup
del ssh_commands.txt
del serverpulse-agent.tar.gz

pause
