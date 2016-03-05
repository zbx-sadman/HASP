## NetHASP 
This is a little Powershell script that fetch metric's values from Sentinel/Aladdin HASP Network Monitor.
Tanx to _Tor_ user for [HaspMonitor.exe](https://www.zabbix.com/forum/showpost.php?p=96243&postcount=4) utility.

Actual release 1.0

**Note**
Since release v1.0 NetHASP Miner do not use _HaspMonitor.exe_ to avoid runtime overheads. Wrapper DLL for _hsmon.dll_ will be compiled on first run of the .ps1. 
By virtue of certain .NET procedures first run will be longer that other. Do not be nervous. 

**Note**
Due _hsmon.dll_ compiled to 32-bit systems, you need to provide 32-bit environment to run all code, that use that DLL. You must use **32-bit instance of PowerShell** to avoid runtime errors while used on 64-bit systems. Its may be placed here: _%WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe_.

Support objects:
- _Server_ - NetHASP server that can detected with "GET SERVERS" command;
- _Module_ - NetHASP Module that can detected with "GET MODULES ..." command;
- _Slot_ - NetHASP Slot that can detected with "GET SLOTS ..." command;
- _Login_ - NetHASP Login that can detected with "GET LOGINS ..." command.

Actions:
- _Discovery_ - Make Zabbix's LLD JSON;
- _Get_       - Get metric of object collection's item;
- _Count_     - Count collection's items.
- _DoCommand_ - Do NetHASP Monitîr command that not required connection to server (HELP, VERSION). Command must be specified with -Key parameter

Zabbix's LLD available to: 
- _Server_ ;
- _Module_ ;
- _Slot_ ;
- _Login_ ;

###How to use standalone
At First - change inside .ps1 _HSMON_LIB_PATH_ variable's value to other, which point to place, where you store _hsmon.dll_ and _nethasp.ini_.

Now running of Miner so simple - just use parameters to specify:
- _-Action_  - what need to do with collection or its item;
- _-Object_  - rule to make collection;
- _-Key_     - "path" to collection item's metric;
- _-ServerID_ - to select NetHASP server from list;
- _-ModuleID_ - to additional objects selecting by Module Address;
- _-SlotID_   - to additional objects selecting by Slot;
- _-LoginID_  - to additional objects selecting by login Index;
- _-ErrorCode_ - what must be returned if any process error will be reached;
- _-ConsoleCP_ - codepage of Windows console. Need to properly convert output to UTF-8;
- _-DefaultConsoleWidth_ - to leave default console width and not grow its to $CONSOLE_WIDTH (see .ps1 code);
- _-Verbose_ - to enable verbose messages;

    # Get output of NetHASP Monitor VERSION command
    powershell -NoProfile -ExecutionPolicy "RemoteSigned" -File "nethasp.ps1" -Action "DoCommand" -Key "VERSION" -defaultConsoleWidth

    # Make Zabbix's LLD JSON for NetHASP servers
    ... nethasp.ps1 -Action "Discovery" -Object "Server" 

    # Return number of used licenses on Slot #16 of stuffserver.contoso.com server. If processing error reached - return "-127"  
    ... nethasp.ps1 -Action "Get" -Object "Slot" -Key "CURR" -ServerId "stuffserver.contoso.com" -SlotId "16" -ErrorCode "-127"

    # Show formatted list of 'Module' object(s) metrics. Verbose messages is enabled. Console width is not changed.
    ... nethasp.ps1 -Action "Get" -Object "Module" -defaultConsoleWidth -Verbose

###How to use with Zabbix
1. Just include [zbx_hasp.conf](https://github.com/zbx-sadman/hasp/tree/master/Zabbix_Templates/zbx_hasp.conf) to Zabbix Agent config;
2. Check path to 32-bit PowerShell instance in _zbx_hasp.conf_ and change its if you need;
3. Put _nethasp.ps1, hsmon.dll, nethasp.ini_ to _C:\zabbix\scripts\nethasp_ dir;
4. Change NH_SERVER_ADDR into _nethasp.ini_ to yours NetHASP server or enable Broadcast feature;
5. Make unsigned .ps1 script executable with _Set-ExecutionPolicy RemoteSigned_;
6. Set Zabbix Agent's / Server's _Timeout_ to more that 3 sec (may be 10 or 30);
7. Import [template](https://github.com/zbx-sadman/HASP/tree/master/Zabbix_Templates) to Zabbix Server;
8. At first time run script to do any simply request (like _-Action DoCommand -Key "HELP"_ ) to let self-complie NetHASP monitor library wrapper. Its can be get some time; 
9. Enjoy.

**Note**
Do not try import Zabbix v2.4 template to Zabbix _pre_ v2.4. You need to edit .xml file and make some changes at discovery_rule - filter tags area and change _#_ to _<>_ in trigger expressions. I will try to make template to old Zabbix.

###Hints
- NetHASP server can periodically change Server ID. In this case use _-ServerId_ option with alphanumeric server name, that can be known by running script with  _-Action Get -Object Server_ options;
- To see available metrics, run script only with _-Action Get -Object **Object**_ options;
- To measure script runtime use _-Verbose_ command line switch;
- Use _-ErrorCode_ options for monitoring systems events/triggers to runtime errors detection;
- Running the script with PowerShell 3 and above may be require to enable PowerShell 2 compatible mode.

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
