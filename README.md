## NetHASP 
This is a little Powershell script that fetch metric's values from NetHASP Monitor.
Tanx to _Tor_ user for [HaspMonitor.exe](https://www.zabbix.com/forum/showpost.php?p=96243&postcount=4) utility.

***REWORKED***

Support objects:
- _Server_ - NetHASP server that can detected with "GET SERVERS" command;
- _Slot_ - NetHASP Key Slot that can detected with "GET SLOTS ..." command.

Actions:
- _Discovery_ - Make Zabbix's LLD JSON;
- _Get_       - Get metric of object collection item;
- _Count_     - Count collection items.

Zabbix's LLD available to:
- _Server_ - A little fastest that Slot's LLD, but have few Zabbix's Macros;
- _Slot_ - Slowly, but more usable than Server's LLD, because have linked {#SERVERNAME}, {#SERVERID} & {#MAX} (max available licenses on slot).

###How to use standalone
    # Make Zabbix's LLD JSON for HASP Key Servers
    powershell -NoProfile -ExecutionPolicy "RemoteSigned" -File "nethasp.ps1" -Action "Discovery" -Object "Server"

    # Return number of HASP keys
    ... usbhasp.ps1 -Action "Get" -Object "Slot" -Slot 17 -Key Curr -Id "1CServ.admnet.local"

    ...

###How to use with Zabbix
1. Just add to Zabbix Agent config, which run on any host, that can find NeHASP servers, that string: _UserParameter=nethasp[*], powershell -File C:\zabbix\scripts\nethasp\nethasp.ps1 -Action "$1" -Object "$2" -Key "$3" -Id "$4" -Slot "$5"_;
2. Put _nethasp.ps1, HaspMonitor.exe, hsmon.dll, nethasp.ini_ to _C:\zabbix\scripts\nethasp_ dir;
3. Change NH_SERVER_ADDR into _nethasp.ini_ to yours NetHASP server or enable Broadcast feature;
4. Make unsigned .ps1 script executable with _Set-ExecutionPolicy RemoteSigned_;
5. Set Zabbix Agent's / Server's _Timeout_ to more that 3 sec (may be 10 or 30);
6. Import [template](https://github.com/zbx-sadman/HASP/tree/master/Zabbix_Templates) to Zabbix Server;
7. Enjoy.

**Note**
Do not try import Zabbix v2.4 template to Zabbix _pre_ v2.4. You need to edit .xml file and make some changes at discovery_rule - filter tags area and change _#_ to _<>_ in trigger expressions. I will try to make template to old Zabbix.

###Hints
- All HaspMonitor answers are parsed to hash and available to read with **-Key** option. For example: Result of "GET SERVERINFO,ID=.." request - _HS,ID=1898799265,NAME="StuffSever",PROT="UDP(172.16.0.10)",VER="8.310",OS="WIN32"_  - will be parsed to hash array and can be addressed: _-Key OS_ will return _WIN32_;
- NetHASP server can periodically change Server ID. And you can use **-Id** option with detected with "GET SERVERS" command server name: _-Id "StuffSever"_. Miner detect that name is specified do "GET SERVERS" command, take ID and use it with other operation.


## USBHASP
The same that NetHASP Miner, but used for monitoring Sentinel/Aladdin HASP USB keys, which installed locally or binded with USB/IP.

Actual release 1.0

Tested on Windows Server 2008R2 SP1, USB/IP service, Powershell 2.0

Support objects:
- _USBController_ - "Physical" devices (USB Key, Win32_USBControllerDevice.Antecedent)
- _LogicalDevice_ - "Logical" devices (HASP Key, Win32_USBControllerDevice.Dependent)

Actions:
- _Discovery_ - Make Zabbix's LLD JSON;
- _Get_       - Get metric of object collection item;
- _Count_     - Count collection items.

###How to use standalone

    # Make Zabbix's LLD JSON for USB keys
    powershell -NoProfile -ExecutionPolicy "RemoteSigned" -File "usbhasp.ps1" -Action "Discovery" -Object "USBController"

    # Return number of HASP keys
    ... usbhasp.ps1 -Action "Count" -Object "LogicalDevice"

    # Show formatted list of 'USBController' object metrics selected by PnPId "USB\VID_0529&PID_0001\1&79F5D87&0&01". 
    # Verbose messages is enabled. Note that PNPDeviceID is unique for USB Key, Id - is not.
    ... usbhasp.ps1 -Action "Get" -Object "USBController" -PnPDeviceID "USB\VID_0529&PID_0001\1&79F5D87&0&01" -defaultConsoleWidth -Verbose

###How to use with Zabbix
1. Make setting to make unsigned .ps1 scripts executable for all time with _powershell.exe -command "Set-ExecutionPolicy RemoteSigned"_ or for once with _-ExecutionPolicy_ command line option;
2. Just include [zbx\_hasp.conf](https://github.com/zbx-sadman/HASP/tree/master/Zabbix_Templates/zbx_hasp.conf) to Zabbix Agent config;
3. Move _usbhasp.ps1_ to _C:\zabbix\scripts_ dir;
4. Set Zabbix Agent's / Server's _Timeout_ to more that 3 sec (may be 10 or 30);
5. Import [template](https://github.com/zbx-sadman/HASP/tree/master/Zabbix_Templates) to Zabbix Server;
6. Enjoy again.
 
###Hints
- Be sure that you filter LLD to leave only 'HASP' or 'ALADDIN' records.
