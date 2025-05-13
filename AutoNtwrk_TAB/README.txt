AutoNtwrk Portable Installer
------------------------------

This utility checks your current Wi-Fi SSID and reconnects if it doesn't match the expected one.

Files:
- AutoNtwrk_TAB.ps1: The main script.
- install_TAB.bat: Installs a scheduled task to run the script every 15 mins.

Instructions:
1. Edit AutoNtwrk_TAB.ps1 and replace "Your_Network_Name" with your desired SSID.
2. Run install.bat as administrator.

To uninstall:
Run this in a terminal:
    schtasks /Delete /TN "SSID Checker" /F