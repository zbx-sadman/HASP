## NetHASP
This is a little Powershell script that fetch metric's values from NetHASP Monitor.
Tanx to _Tor_ user for [HaspMonitor.exe](https://www.zabbix.com/forum/showpost.php?p=96243&postcount=4) utility.

Support objects:
- _Server_ - NetHASP server that can detected with "GET SERVERS" command;
- _Slot_ - NetHASP Key Slot that can detected with "GET SLOTS ..." command;

Zabbix's LLD available to:
- _Server_ - A little fastest that Slot's LLD, but have few Zabbix's Macros
- _Slot_ - Slowly, but more usable than Server's LLD, because have linked {#SERVERNAME}, {#SERVERID} & {#MAX} (max available licenses on slot);

How to use:
- Just add to Zabbix Agent config, which run on any host, that can find NeHASP servers, that string: _UserParameter=nethasp[*], powershell -File C:\zabbix\scripts\nethasp\nethasp.ps1 -Action "$1" -Object "$2" -Key "$3" -Id "$4" -Slot "$5"_;
- Put _nethasp.ps1, HaspMonitor.exe, hsmon.dll, nethasp.ini_ to _C:\zabbix\scripts\nethasp_ dir;
- Change NH_SERVER_ADDR into _nethasp.ini_ to yours NetHASP server or enable Broadcast feature;
- Make unsigned .ps1 script executable with _Set-ExecutionPolicy RemoteSigned_;
- Set Zabbix Agent's / Server's _Timeout_ to more that 3 sec (may be 10 or 30);
- Import [template](https://github.com/zbx-sadman/HASP/tree/master/Zabbix_Templates) to Zabbix Server;
- Enjoy.

Hints:
- All HaspMonitor answers are parsed to hash and available to read with **-Key** option. For example: Result of "GET SERVERINFO,ID=.." request - _HS,ID=1898799265,NAME="StuffSever",PROT="UDP(172.16.0.10)",VER="8.310",OS="WIN32"_  - will be parsed to hash array and can be addressed: _-Key OS_ will return _WIN32_;
- NetHASP server can periodically change Server ID. And you can use **-Id** option with detected with "GET SERVERS" command server name: _-Id "StuffSever"_. Miner detect that name is specified do "GET SERVERS" command, take ID and use it with other operation.


## USBHASP
The same that NetHASP Miner, but used for monitoring Sentinel/Aladdin HASP USB keys, which installed locally or binded with USB2IP.

Support objects:
- _USBController_ - "physical" HASP keys (Win32_USBControllerDevice.Antecedent);
- _LogicalDevice_ - "logical" HASP keys (Win32_USBControllerDevice.Dependent);

How to use:
- Put to Zabbix Agent config, which run on host where located HASP USB keys, that string: _UserParameter=usbhasp[*], powershell -File C:\zabbix\scripts\usbhasp.ps1 -Action "$1" -Object "$2" -Key "$3" -Id "$4"_;
- Move _usbhasp.ps1_ to _C:\zabbix\scripts_ dir;
- Make unsigned .ps1 script executable with _Set-ExecutionPolicy RemoteSigned_;
- Set Zabbix Agent's / Server's _Timeout_ to more that 3 sec (may be 10 or 30);
- Import [template](https://github.com/zbx-sadman/HASP/tree/master/Zabbix_Templates) to Zabbix Server;
- Enjoy again.
 
Hints:
- Be sure that you filter LLD to leave only 'HASP' or 'ALADDIN' records.
