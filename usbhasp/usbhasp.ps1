<#
    .SYNOPSIS  
        Return USB (HASP) Device metrics value, count selected objects, make LLD-JSON for Zabbix

    .DESCRIPTION
        Return USB (HASP) Device metrics value, count selected objects, make LLD-JSON for Zabbix

    .NOTES  
        Version: 1.0
        Name: USB HASP Keys Miner
        Author: zbx.sadman@gmail.com
        DateCreated: 29FEB2016
        Testing environment: Windows Server 2008R2 SP1, USB/IP service, Powershell 2.0

    .LINK  
        https://github.com/zbx-sadman

    .PARAMETER Action
        What need to do with collection or its item:
            Discovery - Make Zabbix's LLD JSON;
            Get       - Get metric from collection item;
            Count     - Count collection items.

    .PARAMETER Object
        Define rule to make collection:
            USBController - "Physical" devices (USB Key)
            LogicalDevice - "Logical" devices (HASP Key)

    .PARAMETER Key
        Define "path" to collection item's metric 

    .PARAMETER PnPDeviceID
        Used to select only one item from collection

    .PARAMETER ConsoleCP
        Codepage of Windows console. Need to properly convert output to UTF-8

    .PARAMETER DefaultConsoleWidth
        Say to leave default console width and not grow its to $CONSOLE_WIDTH

    .PARAMETER Verbose
        Enable verbose messages

    .EXAMPLE 
        usbhasp.ps1 -Action "Discovery" -Object "USBController"

        Description
        -----------  
        Make Zabbix's LLD JSON for USB keys

    .EXAMPLE 
        usbhasp.ps1 -Action "Count" -Object "LogicalDevice"

        Description
        -----------  
        Return number of HASP keys

    .EXAMPLE 
        usbhasp.ps1 -Action "Get" -Object "USBController" -PnPDeviceID "USB\VID_0529&PID_0001\1&79F5D87&0&01" -defaultConsoleWidth -Verbose

        Description
        -----------  
        Show formatted list of 'USBController' object metrics selected by PnPId "USB\VID_0529&PID_0001\1&79F5D87&0&01". Verbose messages is enabled
        Note that PNPDeviceID is unique for USB Key, Id - is not.
#>

Param (
        [Parameter(Mandatory = $True)] 
        [string]$Action,
        [Parameter(Mandatory = $True)]
        [string]$Object,
        [Parameter(Mandatory = $False)]
        [string]$Key,
        [Parameter(Mandatory = $False)]
        [string]$PnPDeviceID,
        [Parameter(Mandatory = $False)]
        [string]$ConsoleCP,
        [Parameter(Mandatory = $False)]
        [switch]$DefaultConsoleWidth
      )

# Set US locale to properly formatting float numbers while converting to string
[System.Threading.Thread]::CurrentThread.CurrentCulture = "en-US"

# Width of console to stop breaking JSON lines
Set-Variable -Name "CONSOLE_WIDTH" -Value 255 -Option Constant -Scope Global

####################################################################################################################################
#
#                                                  Function block
#    
####################################################################################################################################
#
#  Select object with ID if its given or with Any ID in another case
#
filter PnPDeviceIDEqualOrAny($PnPDeviceID) { if (($_.PNPDeviceID -Eq $PnPDeviceID) -Or (!$PnPDeviceID)) { $_ } }

#
#  Prepare string to using with Zabbix 
#
Function Prepare-ToZabbix {
  Param (
     [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
     [PSObject]$InObject
  );
  $InObject = ($InObject.ToString());

  $InObject = $InObject.Replace("\", "\\");
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
#  Make & return JSON, due PoSh 2.0 haven't Covert-ToJSON
#
Function Make-JSON {
   Param (
      [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
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

####################################################################################################################################
#
#                                                 Main code block
#    
####################################################################################################################################

# split key
$Keys = $Key.split(".");

Write-Verbose "$(Get-Date) Taking Win32_USBControllerDevice with WMI"
$Objects = Get-WmiObject Win32_USBControllerDevice;
if (!$Objects)
   {
     Write-Warning "$(Get-Date) No devices found";
     Exit;
   }

Write-Verbose "$(Get-Date) Creating collection of specified object: '$Object'";
switch ($Object) {
   'LogicalDevice' { 
      $Objects = $Objects | % { [Wmi]$_.Dependent}; 
   }
   'USBController' { 
      # Need to take Unique items due Senintel used multiply logical devices linked to physical keys. 
      # As a result - double "physical" device items into 'Antecedent' branch
      $Objects = $Objects | % { [Wmi]$_.Antecedent } | Get-Unique; 
   }
   default         {
      Write-Error "Unknown object: '$Object'";
      Exit;
   }
}

$Objects = $Objects | PnPDeviceIDEqualOrAny $PnPDeviceID
if (!$Objects)
   {
     Write-Error "$(Get-Date) No devices selected";
     Exit;
   }
 
Write-Verbose "$(Get-Date) Processing collection with action: '$Action' ";
switch ($Action) {
   # Discovery given object, make json for zabbix
  'Discovery' {
      Write-Verbose "$(Get-Date) Generating LLD JSON";
      $ObjectProperties = @("NAME", "PNPDEVICEID");
      $Objects | % { $_.PNPDeviceID = $_.PNPDeviceID | Prepare-ToZabbix };
      $Result = $Objects | Make-JSON -ObjectProperties $ObjectProperties -Pretty;
  }
  # Get metrics or metric list
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
  default  { 
     Write-Error "Unknown action: '$Action'";
     Exit;
  }  
}

Write-Verbose "$(Get-Date) Converting Windows DataTypes to equal Unix's / Zabbix's";
switch (($Result.GetType()).Name) {
   'Boolean'  { $Result = [int]$Result; }
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
