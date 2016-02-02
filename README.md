## NetHASP Miner 
This is a little Powershell script that fetch metric's values from NetHASP Monitor.
Tanx to _Tor_ user for [HaspMonitor.exe](https://www.zabbix.com/forum/showpost.php?p=96243&postcount=4) utility.

Support objects:
- _Server_ - NetHASP server that can detected with "GET SERVERS" command;
- _Slot_ - NetHASP Key Slot that can detected with "GET SLOTS ..." command;

Zabbix's LLD available to:
- _Server_ - A little fastest that Slot's LLD, but have few Zabbix's Macros
- _Slot_ - Slowly, but more usable than Server's LLD, because have linked {#SERVERNAME}, {#SERVERID} & {#MAX} (max available licenses on slot);

How to use:
- Just add to Zabbix Agent config, which run on WSUS host this string: _UserParameter=nethasp.miner[*], powershell -File C:\zabbix\nethasp\nethasp.ps1 -Action "$1" -Object "$2" -Key "$3" -Id "$4" -Slot "$5"
- Put _nethasp\_miner.ps1, HaspMonitor.exe, hsmon.dll, nethasp.ini_ to _C:\zabbix\nethasp_ dir;
- Change NH_SERVER_ADDR into _nethasp.ini_ to yours NetHASP server or enable Broadcast feature;
- Make unsigned .ps1 script executable with _Set-ExecutionPolicy RemoteSigned_;
- Set Zabbix Agent's / Server's _Timeout_ to more that 3 sec (may be 10 or 30);
- Import [template](https://github.com/zbx-sadman/nethasp_miner/tree/master/Zabbix_Templates) to Zabbix Server;
- Enjoy.

Hints:
- All HaspMonitor answers are parsed to hash and available to read with **-Key** option. For example: Result of "GET SERVERINFO,ID=.." request - "HS,ID=1898799265,NAME=\"StuffSever\",PROT=\"UDP(172.16.0.10)\",VER=\"8.310\",OS=\"WIN32\""  - will be parsed to hash array and can be addressed: _-Key OS_ will return "WIN32"
- NetHASP server can periodically change server ID. And you can use *-Id* option with detected with "GET SERVERS" command server name: -Id "StuffSever". Miner detect that name is specified and do "GET SERVERS" command, take ID and use it with other operation.


