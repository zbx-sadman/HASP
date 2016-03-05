<#
    .SYNOPSIS  
        Return Sentinel/Aladdin HASP Network Monitor metrics value, make LLD-JSON for Zabbix

    .DESCRIPTION
        Return Sentinel/Aladdin HASP Network Monitor metrics value, make LLD-JSON for Zabbix

    .NOTES  
        Version: 1.0
        Name: Aladdin HASP Network Monitor Miner
        Author: zbx.sadman@gmail.com
        DateCreated: 05MAR2016
        Testing environment: Windows Server 2008R2 SP1, Powershell 2.0, Aladdin HASP Network Monitor DLL 2.5.0.0 (hsmon.dll)

        Due _hsmon.dll_ compiled to 32-bit systems, you need to provide 32-bit environment to run all code, that use that DLL. You must use **32-bit instance of PowerShell** to avoid runtime errors while used on 64-bit systems. Its may be placed here:_%WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe.

    .LINK  
        https://github.com/zbx-sadman

    .PARAMETER Action
        What need to do with collection or its item:
            Discovery - Make Zabbix's LLD JSON;
            Get       - Get metric from collection's item;
            Count     - Count collection's items.
            DoCommand - Do NetHASP Monitor command that not require connection to server (HELP, VERSION). Command must be specified with -Key parameter

    .PARAMETER Object
        Define rule to make collection:
            Server - NetHASP server (detected with "GET SERVERS" command);
            Slot - NetHASP key slot ("GET SLOTS ...");
            Module - NetHASP module ("GET MODULES ...");
            Login - authorized connects to NetHASP server ("GET LOGINS ...").

    .PARAMETER Key
        Define "path" to collection item's metric 

    .PARAMETER ServerID
        Used to select NetHASP server from list. 
        ServerID can be numeric (real ID) or alphanumeric (server name)
        Server name must be taked from field "NAME" of the "GET SERVERS" command output ('stuffserver.contoso.com' or similar).

    .PARAMETER ModuleID
        Used to additional objects selecting by Module Address

    .PARAMETER SlotID
        Used to additional objects selecting by Slot

    .PARAMETER LoginID
        Used to additional objects selecting by login Index

    .PARAMETER ErrorCode
        What must be returned if any process error will be reached

    .PARAMETER ConsoleCP
        Codepage of Windows console. Need to properly convert output to UTF-8

    .PARAMETER DefaultConsoleWidth
        Say to leave default console width and not grow its to $CONSOLE_WIDTH

    .PARAMETER Verbose
        Enable verbose messages

    .EXAMPLE 
        powershell -NoProfile -ExecutionPolicy "RemoteSigned" -File "nethasp.ps1" -Action "DoCommand" -Key "VERSION" -defaultConsoleWidth

        Description
        -----------  
        Get output of NetHASP Monitor VERSION command

    .EXAMPLE 
        nethasp.ps1 -Action "Discovery" -Object "Server" 

        Description
        -----------  
        Make Zabbix's LLD JSON for NetHASP servers

    .EXAMPLE 
        nethasp.ps1 -Action "Get" -Object "Slot" -Key "CURR" -ServerId "stuffserver.contoso.com" -SlotId "16" -ErrorCode "-127"

        Description
        -----------  
        Return number of used licenses on Slot #16 of stuffserver.contoso.com server. If processing error reached - return "-127"  

    .EXAMPLE 
        usbhasp.ps1 -Action "Get" -Object "Module" -defaultConsoleWidth -Verbose

        Description
        -----------  
        Show formatted list of 'Module' object(s) metrics. Verbose messages is enabled. Console width is not changed.
#>

Param (
        [Parameter(Mandatory = $True)] 
        [string]$Action,
        [Parameter(Mandatory = $False)]
        [string]$Object,
        [Parameter(Mandatory = $False)]
        [string]$Key,
        [Parameter(Mandatory = $False)]
        [string]$ServerId,
        [Parameter(Mandatory = $False)]
        [string]$ModuleId,
        [Parameter(Mandatory = $False)]
        [string]$SlotId,
        [Parameter(Mandatory = $False)]
        [string]$LoginId,
        [Parameter(Mandatory = $False)]
        [string]$ErrorCode,
        [Parameter(Mandatory = $False)]
        [string]$ConsoleCP,
        [Parameter(Mandatory = $False)]
        [switch]$DefaultConsoleWidth
      );

# Set US locale to properly formatting float numbers while converting to string
[System.Threading.Thread]::CurrentThread.CurrentCulture = "en-US";

# Width of console to stop breaking JSON lines
Set-Variable -Name "CONSOLE_WIDTH" -Value 255 -Option Constant -Scope Global;

# Path to store dir for libs and ini files.
Set-Variable -Name "HSMON_LIB_PATH" -Value "C:\\zabbix\\scripts\\nethasp\\" -Option Constant -Scope Global;
#Set-Variable -Name "HSMON_LIB_PATH" -Value "D:\\pshell\\" -Option Constant -Scope Global

# Full paths to hsmon.dll and nethasp.ini
Set-Variable -Name "HSMON_LIB_FILE" -Value "$($HSMON_LIB_PATH)hsmon.dll" -Option Constant -Scope Global;
Set-Variable -Name "HSMON_INI_FILE" -Value "$($HSMON_LIB_PATH)nethasp.ini" -Option Constant -Scope Global;

# Full path to hsmon.dll wrapper, that compiled by this script
Set-Variable -Name "WRAPPER_LIB_FILE" -Value "$($HSMON_LIB_PATH)wraphsmon.dll" -Option Constant -Scope Global;

# Timeout in seconds for "SCAN SERVERS" connection stage
Set-Variable -Name "HSMON_SCAN_TIMEOUT" -Value 5 -Option Constant -Scope Global;

# Enumerate Objects. [int][NetHASPObjects]::DumpObject equal 0 due [int][NetHASPObjects]::AnyNonexistItem equal 0 too
Add-Type -TypeDefinition "public enum NetHASPObjects { DumpObject, Server, Module, Slot, Login }";

####################################################################################################################################
#
#                                                  Function block
#    
####################################################################################################################################

#
#  Select object with ID if its given or with Any ID in another case
#
filter IDEqualOrAny($Property, $Id) { if (($_.$Property -Eq $Id) -Or (!$Id)) { $_ } }


#
#  Prepare string to using with Zabbix 
#
Function Prepare-ToZabbix {
  Param (
     [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
     [PSObject]$InObject
  );
  $InObject = ($InObject.ToString());

  $InObject = $InObject.Replace("`"", "\`"");

  $InObject;
}

#
#  Convert incoming object's content to UTF-8
#
function ConvertTo-Encoding ([string]$From, [string]$To){  
   Begin   {  
      $encFrom = [System.Text.Encoding]::GetEncoding($from)  
      $encTo = [System.Text.Encoding]::GetEncoding($to)  
   }  
   Process {  
      $bytes = $encTo.GetBytes($_)  
      $bytes = [System.Text.Encoding]::Convert($encFrom, $encTo, $bytes)  
      $encTo.GetString($bytes)  
   }  
}

#
#  Return value of object's metric defined by key-chain from $Keys Array
#
Function Get-Metric { 
   Param (
      [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
      [PSObject]$InObject, 
      [array]$Keys
   ); 
   # Expand all metrics related to keys contained in array step by step
   $Keys | % { if ($_) { $InObject = $InObject | Select -Expand $_ }};
   $InObject;
}

#
#  Convert Windows DateTime to Unix timestamp and return its
#
Function ConvertTo-UnixTime { 
   Param (
      [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
      [PSObject]$EndDate
   ); 

   Begin   { 
      $StartDate = Get-Date -Date "01/01/1970"; 
   }  

   Process { 
      # Return unix timestamp
      (New-TimeSpan -Start $StartDate -End $EndDate).TotalSeconds; 
   }  
}


#
#  Make & return JSON, due PoSh 2.0 haven't Covert-ToJSON
#
Function Make-JSON {
   Param (
      [Parameter(Mandatory = $True, ValueFromPipeline = $true)] 
      [PSObject]$InObject, 
      [array]$ObjectProperties, 
      [switch]$Pretty
   ); 
   Begin   {
               # Pretty json contain spaces, tabs and new-lines
               if ($Pretty) { $CRLF = "`n"; $Tab = "    "; $Space = " "; } else {$CRLF = $Tab = $Space = "";}
               # Init JSON-string $InObject
               $Result += "{$CRLF$Space`"data`":[$CRLF";
               # Take each Item from $InObject, get Properties that equal $ObjectProperties items and make JSON from its
               $itFirstObject = $True;
           } 
   Process {
               ForEach ($Object in $InObject) {
                  if (-Not $itFirstObject) { $Result += ",$CRLF"; }
                  $itFirstObject=$False;
                  $Result += "$Tab$Tab{$Space"; 
                  $itFirstProperty = $True;
                  # Process properties. No comma printed after last item
                  ForEach ($Property in $ObjectProperties) {
                     if (-Not $itFirstProperty) { $Result += ",$Space" }
                     $itFirstProperty = $False;
                     $Result += "`"{#$Property}`":$Space`"$($Object.$Property | Prepare-ToZabbix)`""
                  }
                  # No comma printed after last string
                  $Result += "$Space}";
               }
           }
  End      {
               # Finalize and return JSON
               "$Result$CRLF$Tab]$CRLF}";
           }
}

function Compile-WrapperDLL() {
   $WrapperSourceCode = 
@"
   using System;
   using System.Runtime.InteropServices;
   using System.Text;
   
   namespace HASP { 
      public class Monitor { 
         [DllImport(`"$($HSMON_LIB_FILE)`", CharSet = CharSet.Ansi,EntryPoint=`"mightyfunc`", CallingConvention=CallingConvention.Cdecl)]
         // String type used for request due .NET do auto conversion to Ansi char* with marshaliing procedure;
         // Byte[] type used for response due .NET char* is 2-byte, but mightyfunc() need to 1-byte Ansi char;
         // Int type used for responseBufferSize due .NET GetString() operate with [int] params. So, response lenght must be Int32 sized
         extern static unsafe void mightyfunc(string request, byte[] response, int *responseBufferSize);
     
         public Monitor() {}
      
         public static unsafe string doCmd(string request) {
            int responseBufferSize = 10240, responseLenght = 0;
            byte[] response = new byte[responseBufferSize];
            string returnValue = `"`";
            mightyfunc(request, response, &responseBufferSize);
            while (response[responseLenght++] != '\0') 
            returnValue = System.Text.Encoding.UTF8.GetString(response, 0, responseLenght);
            return returnValue;
         }

      } 
   }
"@

   $CompilerParameters = New-Object -TypeName System.CodeDom.Compiler.CompilerParameters;
   $CompilerParameters.CompilerOptions = "/unsafe /platform:x86";
   $CompilerParameters.OutputAssembly = $WRAPPER_LIB_FILE;
   Add-Type -TypeDefinition $WrapperSourceCode -Language CSharp -CompilerParameters $CompilerParameters;
   If ($False -eq (Test-Path $WRAPPER_LIB_FILE)) {
      Write-Warning "Wrapper library not found after compilation. Something wrong";
      Exit;
   }
}

#
#  Exit with specified ErrorCode or Warning message
#
Function Exit-WithMessage { 
   Param (
      [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
      [String]$Message 
   ); 
   if ($ErrorCode) { 
      Write-Output ($ErrorCode);
   } else {
      Write-Warning ($Message);
   }
   Exit;
}

# Is this a Wow64 powershell host
function Test-Wow64() {
    return (Test-Win32) -and (test-path env:\PROCESSOR_ARCHITEW6432)
}

# Is this a 64 bit process
function Test-Win64() {
    return [IntPtr]::size -eq 8
}

# Is this a 32 bit process
function Test-Win32() {
    return [IntPtr]::size -eq 4
}

Function Get-NetHASPData {
   Param (
      [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
      [String]$HASPMonitorCommand,
      [Switch]$SkipScanning,
      [Switch]$ReturnPlainText
   );
   # Interoperation to NetHASP stages:
   #    1. Set configuration (point to .ini file)
   #    2. Scan servers while STATUS not OK or Timeout not be reached
   #    3. Do one or several GET* command   

   # Init connect to NetHASP module?   
   if (-Not $SkipScanning) {
      # Processing stage 1
      Write-Verbose "$(Get-Date) Stage #1. Initializing NetHASP monitor session"
      $ret = ([HASP.Monitor]::doCmd("SET CONFIG,FILENAME=$HSMON_INI_FILE")).Trim();
      if ("OK" -ne $ret) { 
         Exit-WithMessage("Error 'SET CONFIG' command: $ret"); 
      }
   
      # Processing stage 2
      Write-Verbose "$(Get-Date) Stage #2. Scan NetHASP servers"
      $ret = [HASP.Monitor]::doCmd("SCAN SERVERS");
      $ScanSec = 0;
      do {
         # Wait a second before check process state
         Start-Sleep -seconds 1
         $ScanSec++; $ret = ([HASP.Monitor]::doCmd("STATUS")).Trim();
         #Write-Verbose "$(Get-Date) Status: $ret"
      } while (("OK" -ne $ret) -And ($ScanSec -lt $HSMON_SCAN_TIMEOUT))

      # Scanning timeout :(
      if ($ScanSec -eq $HSMON_SCAN_TIMEOUT) {
            Exit-WithMessage("'SCAN SERVERS' command error: timeout reached");
        }
    }

   # Processing stage 3
   Write-Verbose "$(Get-Date) Stage #3. Execute '$HASPMonitorCommand' command";
   $ret = ([HASP.Monitor]::doCmd($HASPMonitorCommand)).Trim();

   if ("EMPTY" -eq $ret) {
      Exit-WithMessage("No data recieved");
   } else {
      if ($ReturnPlainText) {
        # Return unparsed output 
        $ret;
      } else {
        # Parse output and make PSObjects list to return
        $ret -Split "`r`n" -Replace "`"" | ? {$_} | % {$_ -Split "," | % {$r = @{}} {$k,$v = $_.split("="); $r.$k = $v} {New-Object PSObject -Property $r}};
      }
   }
}


####################################################################################################################################
#
#                                                 Main code block
#    
####################################################################################################################################
Write-Verbose "$(Get-Date) Checking runtime environment...";

# Script running into 32-bit environment?
if ($False -eq (Test-Wow64)) {
   Write-Warning "You must run this script with 32-bit instance of Powershell, due wrapper interopt with 32-bit Windows Library";
   Write-Warning "Try to use %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -File `"$($MyInvocation.InvocationName)`" [-OtherOptions ...]";
   Exit;
}

Write-Verbose "$(Get-Date) Checking wrapper library for HASP Monitor availability...";
If ($False -eq (Test-Path $WRAPPER_LIB_FILE)) {
   Write-Verbose "$(Get-Date) Wrapper library not found, try compile it";
   Write-Verbose "$(Get-Date) First wrapper library loading can get a few time. Please wait...";
   Compile-WrapperDLL; 
#   [HASP.Monitor]::doCmd("VERSION");
} else {
  Write-Verbose "$(Get-Date) Loading wrapper library";
  Add-Type -Path $WRAPPER_LIB_FILE;
}

# Need to run one HASP command like HELP, VERSION?
if ('DoCommand' -eq $Action) {
   if ($Key) {
       Write-Verbose "$(Get-Date) Just do command '$Key'";
       ([HASP.Monitor]::doCmd($Key)).Trim();
   } else {
      Exit-WithMessage("No HASPMonitor command given with -Key option");
   }
   exit;
}

$Keys = $Key.split(".");

# Exit if object is not [NetHASPObjects]
if (0 -eq [int]($Object -As [NetHASPObjects])) { Exit-WithMessage ("Unknown object: '$Object'"); }

Write-Verbose "$(Get-Date) Creating collection of specified object: '$Object'";
# Object must contain Servers data?
if (($Object -As [NetHASPObjects]) -ge [NetHASPObjects]::Server) {
   Write-Verbose "$(Get-Date) Getting server list";
   $Servers = "GET SERVERS" | Get-NetHASPData; 
   if (-Not $Servers) { 
      Exit-WithMessage ("No NetHASP servers found");
   }

   Write-Verbose "$(Get-Date) Checking server ID";
   if ($ServerId) {
      # Is Server Name into $ServerId
      if (-Not [regex]::IsMatch($ServerId,'^\d+$')) {
         # Taking real ID if true
         Write-Verbose "$(Get-Date) ID ($ServerId) was not numeric - probaly its hostname, try to find ID in servers list";
         $ServerId = ($Servers | ? {$_.Name -eq $ServerId}).Id;
         if (-Not $ServerId) {
            Exit-WithMessage ("Server not found");
         }
         Write-Verbose "$(Get-Date) Got ID = $ServerId";
      }
   }
   Write-Verbose "$(Get-Date) Filtering... (ID=$ServerId)";
   $Servers = $Servers | IDEqualOrAny "Id" $ServerId;
   $Objects = $Servers;
}

# Object must be processed with Servers data?
if (($Object -As [NetHASPObjects]) -ge [NetHASPObjects]::Module) {
   Write-Verbose "$(Get-Date) Getting modules list"; 
   $Modules = $Servers | % { "GET MODULES,ID=$($_.Id)" | Get-NetHASPData -SkipScanning} | IDEqualOrAny "MA" $ModuleId;
   $Objects = $Modules;
}

# Object must be processed with Servers+Modules data?
if (($Object -As [NetHASPObjects]) -ge [NetHASPObjects]::Slot) {
   Write-Verbose "$(Get-Date) Getting slots list";
   $Slots = $Modules | % { "GET SLOTS,ID=$($_.Id),MA=$($_.Ma)" | Get-NetHASPData -SkipScanning} | IDEqualOrAny "Slot" $SlotId;
   $Objects = $Slots;
}

# Object must be processed with Servers+Modules+Slots data?
if (($Object -As [NetHASPObjects]) -ge [NetHASPObjects]::Login) {
   Write-Verbose "$(Get-Date) Getting logins list";
   # LOGININFO ignore INDEX param and return list of Logins anyway
   $Logins = $Slots | % { "GET LOGINS,ID=$($_.Id),MA=$($_.Ma),SLOT=$($_.Slot)" | Get-NetHASPData -SkipScanning} | IDEqualOrAny "Index" $LoginId;
   $Objects = $Logins;
}

if (-Not $Objects) { 
   Exit-WithMessage ("No objects found");
}

$Objects | % { $_ | Add-Member -MemberType NoteProperty -Name "ServerName" -Value ($Servers | IDEqualOrAny "Id" $_.Id).Name;
               $_ | Add-Member -MemberType NoteProperty -Name "ServerId" -Value $_.Id; }

Write-Verbose "$(Get-Date) Collection created";
#$Objects 
#exit
Write-Verbose "$(Get-Date) Processing collection with action: '$Action'";
switch ($Action) {
   'Discovery' {
       switch ($Object) {
          'Server' {
             $ObjectProperties = @("SERVERNAME", "SERVERID");
          }
          'Module' {
             # MA - module address 
             $ObjectProperties = @("SERVERNAME", "SERVERID", "MA", "MAX");
          }
          'Slot'   {
             $ObjectProperties = @("SERVERNAME", "SERVERID", "MA", "SLOT", "MAX");
          }
          'Login' {
             $ObjectProperties = @("SERVERNAME", "SERVERID", "MA", "SLOT", "INDEX", "NAME");
          }
          default  { Exit-WithMessage ("Unknown object: '$Object'"); }
       }
       Write-Verbose "$(Get-Date) Generating LLD JSON";
       $Result = $Objects | Make-JSON -ObjectProperties $ObjectProperties -Pretty;
   }
   'Get' {
      if ($Keys) { 
         Write-Verbose "$(Get-Date) Getting metric related to key: '$Key'";
         $Result = $Objects | Get-Metric -Keys $Keys;
      } else { 
         Write-Verbose "$(Get-Date) Getting metric list due metric's Key not specified";
         $Result = $Objects | fl *;
      };
    }
    # Count selected objects
    'Count' { 
       Write-Verbose "$(Get-Date) Counting objects";  
       # if result not null, False or 0 - return .Count
       $Result = $(if ($Objects) { @($Objects).Count } else { 0 } ); 
    }
   default  { Exit-WithMessage ("Unknown action: '$Action'"); }
}  

Write-Verbose "$(Get-Date) Converting Windows DataTypes to equal Unix's / Zabbix's";
switch (($Result.GetType()).Name) {
   'Boolean'  { $Result = [int]$Result; }
   'DateTime' { $Result = $Result | ConvertTo-UnixTime; }
   'Object[]' { $Result = $Result | Out-String; }
}

# Normalize String object
$Result = $Result.ToString().Trim();

# Convert string to UTF-8 if need (For Zabbix LLD-JSON with Cyrillic chars for example)
if ($consoleCP) { 
   Write-Verbose "$(Get-Date) Converting output data to UTF-8";
   $Result = $Result | ConvertTo-Encoding -From $consoleCP -To UTF-8; 
}

# Break lines on console output fix - buffer format to 255 chars width lines 
if (!$defaultConsoleWidth) { 
   Write-Verbose "$(Get-Date) Changing console width to $CONSOLE_WIDTH";
   mode con cols=$CONSOLE_WIDTH; 
}

Write-Verbose "$(Get-Date) Finishing";

"$Result";
