<#
NetHASP Miner
Version 0.9

Return NetHASP metrics values, make LLD-JSON for Zabbix

zbx.sadman@gmail.com (c) 2016
https://github.com/zbx-sadman
#>

Param (
[string]$Action,
[string]$Object,
[string]$Key,
[string]$Id,
[string]$Slot,
[string]$consoleCP
)

Function Get-NetHASPData {
   Param ([String]$StageCommand);

   $HaspMonitor = "C:\zabbix\nethasp\HaspMonitor.exe"
   $HaspInitFile = "C:\zabbix\nethasp\nethasp.ini"
   $StageCommands = @("SET CONFIG,FILENAME=$HaspInitFile", "SCAN SERVERS")
   $StageCommands += $StageCommand

   $ExecuteResults =  (&$HaspMonitor ($StageCommands)) -Split "`r`n" | ? {$_} | % { $_ -Replace "`""} | % {$a = @()} {$a += $_ -Split "," | % {$r = @{}} {$k,$v = $_.split("="); $r[$k] = $v} {$r}} {$a}
   $Result = New-Object PSObject -Property @{ "msg" = ""; "isSuccess" = $False; "Data" = @() };  

   # Test Stage 0 response
   if (-Not $ExecuteResults[0].ContainsKey("OK")) {
      $Result.msg = "Stage 0 ($($StageCommands[0])) error: $($ExecuteResults[0].MSG)";
  # Test Stage 1 response
   } elseif (-Not $ExecuteResults[1].ContainsKey("OK")) {
      $Result.msg = "Stage 1 ($($StageCommands[1])) error: $($ExecuteResults[1].MSG)";
  # Test Stage 3 response
   } elseif (-Not $ExecuteResults[2] -Or $ExecuteResults[2].ContainsKey("EMPTY")) {
      $Result.msg = "Stage 2 error: no data recieved";
  # No errors found. Request result processeed
   } else {
      $Result.isSuccess = $True;
      $Result.Data = $ExecuteResults | ? { -not $_.ContainsKey("OK") }
   }
   if (-Not $Result.isSuccess) {
     Write-Host $Result.Msg; exit;
   } else {
     $Result;
   }
}



Function Make-JSON {
  Param ([PSObject]$InObject, [array]$ObjectProperties, [boolean]$Pretty);
  # Pretty json contain spaces, tabs and new-lines
  if ($Pretty) { $CRLF = "`n"; $Tab = "    "; $Space = " "; } else {$CRLF = $Tab = $Space = "";}
  # Init JSON-string $InObject
  $Result = "{$CRLF$Space`"data`":[$CRLF";
  # Take each Item from $InObject, get Properties that equal $ObjectProperties items and make JSON from its
  $k = 0;
  ForEach ($Object in $InObject) {$k++;
     $Result += "$Tab$Tab{$Space";
     # Process properties. No comma printed after last item
     $ObjectProperties | % {$i = 0} {$i++; $Result += "`"{#$_}`":$Space`"$($Object.$_)`"$(&{if ($i -lt ($ObjectProperties | Measure).Count) {",$Space"} })"}
     # No comma printed after last string
     $Result += " }$(&{if ($k -lt ($InObject | Measure).Count) {",$Space"} })$CRLF";
  }
  # Finalize and return JSON
  "$Result$Space]$CRLF}";
}

# if needProcess is False - $Result is not need to convert to string and etc 
$needProcess = $True;

# Is Server Name into $Id
if (-Not [regex]::IsMatch($Id,'^\d+$')) {
  # Taking real ID if true
  $Id = (Get-NetHASPData -StageCommand "GET SERVERS" | ? {$_.Data.Name -eq $Id}).Data.ID
}

switch ($Action) {
     #
     # Discovery given object, make json for zabbix
     #
     ('Discovery') {
         $needProcess = $False;
         switch ($Object) {
            ('Server') {
                $Result = Get-NetHASPData -StageCommand "GET SERVERS"; 
                $InObject = $Result.Data; 
                $ObjectProperties = @("NAME", "ID");
            }
            ('Slot')   {
                $Servers = Get-NetHASPData -StageCommand "GET SERVERS"; 
                $Slots = $Servers | % { Get-NetHASPData -StageCommand "GET SLOTS,MA=1,ID=$($_.Data.ID)" }
                $InObject = $Slots | % {$a = @()} { $cid = $_.Data.ID; $a += @{"SERVERNAME" = ($Servers | ? {$_.Data.ID -eq $cid}).Data.Name; "SERVERID" = $_.Data.ID; "SLOT" = $_.Data.Slot;  "MAX" = $_.Data.Max}} {$a}
                $ObjectProperties = @("SERVERNAME", "SERVERID", "SLOT", "MAX");
            }
            default    { $needProcess = $False; $Result = "Incorrect object: '$Object'";}
         }
        $Result = Make-JSON -InObject $InObject -ObjectProperties $ObjectProperties -Pretty $True;
     }
     #
     # Get metrics from object (real or virtual)
     #
     ('Get') {
        switch ($Object) {
            ('Server')  {
              $Result = Get-NetHASPData -StageCommand "GET SERVERINFO,MA=1,ID=$Id";
            }
            ('Slot')  {
              $Result = Get-NetHASPData -StageCommand "GET SLOTINFO,MA=1,ID=$Id,SLOT=$Slot";
            }
            default   { $needProcess = $False; $Result = "Incorrect object: '$Object'";}
        }  
        $Result = &{ if ($needProcess -And $Result.IsSuccess -And $Key) { $Result.Data.$Key.ToString() } else {""} }
     }
     #
     # Error
     #
     default  { $Result = "Incorrect action: '$Action'"; }
}  
# Break lines on console output fix - buffer format to 255 chars width lines 
mode con cols=255

# Normalize String object
($Result | Out-String).trim();

