<#

USB HASP Keys Miner
Version 0.9

Return USB HASP key metric values, make LLD-JSON for Zabbix

zbx.sadman@gmail.com (c) 2016
https://github.com/zbx-sadman

Actions: Discovery, Get
Objects: USBController, LogicalDevice
Id: Win32_USBControllerDevice.{Antecedent | Dependent}.PNPDeviceID


#>

Param (
[string]$Action,
[string]$Object,
[string]$Key,
[string]$Id
)


Function Prepare-IDToLLD {
  Param ([PSObject]$InObject);
  $InObject = ($InObject.ToString());
  $InObject.Replace("\", "\\");
}

Function Make-JSON {
  Param ([PSObject]$InObject, [array]$ObjectProperties, [switch]$Pretty);
  # Pretty json contain spaces, tabs and new-lines
  if ($Pretty) { $CRLF = "`n"; $Tab = "    "; $Space = " "; } else {$CRLF = $Tab = $Space = "";}
  # Init JSON-string $InObject
  $Result += "{$CRLF$Space`"data`":[$CRLF";
  # Take each Item from $InObject, get Properties that equal $ObjectProperties items and make JSON from its
  $itFirstObject = $True;
  ForEach ($Object in $InObject) {
     if (-Not $itFirstObject) { $Result += ",$CRLF"; }
     $itFirstObject=$False;
     $Result += "$Tab$Tab{$Space"; 
     $itFirstProperty = $True;
     # Process properties. No comma printed after last item
     ForEach ($Property in $ObjectProperties) {
        if (-Not $itFirstProperty) { $Result += ",$Space" }
        $itFirstProperty = $False;
        $Result += "`"{#$Property}`":$Space`"$($Object.$Property)`""
     }
     # No comma printed after last string
     $Result += "$Space}";
  }
  # Finalize and return JSON
  "$Result$CRLF$Tab]$CRLF}";
}

# if needProcess is False - $Result is not need to convert to string and etc 
$needProcess = $True;
$needAction = $True;

$ConnectedUSBDevices = Get-WmiObject Win32_USBControllerDevice;
$ObjectProperties = @("NAME", "PNPDEVICEID");

switch ($Object) {
   'LogicalDevice' { $ConnectedUSBDevices = $ConnectedUSBDevices | % { [Wmi]$_.Dependent}; }
   'USBController' { $ConnectedUSBDevices = $ConnectedUSBDevices | % { [Wmi]$_.Antecedent } | Get-Unique; }
   default  { $Result = "Incorrect object: '$Object'"; $needAction = $False; }
}

if ($needAction) {
   switch ($Action) {
       #
       # Discovery given object, make json for zabbix
       #
       'Discovery' {
           $needProcess = $False;
           $ConnectedUSBDevices | % { $_.PNPDeviceID = Prepare-IDToLLD($_.PNPDeviceID) };
           $Result = Make-JSON -InObject $ConnectedUSBDevices -ObjectProperties $ObjectProperties -Pretty;
       }
       #
       # Get metrics from object (real or virtual)
       #
       'Get' {
          $Result = $ConnectedUSBDevices | ? { $_.PNPDeviceID -eq $Id };
          if ($needProcess -And $Key) { $Result = $Result.$Key.ToString(); }
       }
       #
       # Error
       #
       default  { $Result = "Incorrect action: '$Action'"; }
   }  
}
# Break lines on console output fix - buffer format to 255 chars width lines 
mode con cols=255

# Normalize String object
($Result | Out-String).trim();

