<#
Copyright (c) 2012-2014 VMware, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>

## Author: Jerry Liu, liuj@vmware.com

Param (
	$serverAddress, 
	$serverUser="root", 
	$serverPassword=$env:defaultPassword, 
	$vmName, 
	$guestUser="administrator", 
	$guestPassword=$env:defaultPassword,  
	$ssName="", 
	$updateServer="internal", 
	$severity="Critical",
	$emailTo,
	$uvsId
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

if (verifyIp($vmName)) {
	$ip = $vmName
} else {
	$server = newServer $serverAddress $serverUser $serverPassword
	$vm = newVmWin $server $vmName $guestUser $guestPassword
	if ($ssName) {
		$vm.restoreSnapshot($ssName)
		$vm.start()
	}
	$vm.waitfortools()
	$ip = $vm.getIPv4()
	$vm.enablePsRemote()
}

$remoteWin = newRemoteWin $ip $guestUser $guestPassword

$cmd = {
	$objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
	$objSession = New-Object -ComObject "Microsoft.Update.Session"
	$objSearcher = $objSession.CreateUpdateSearcher()

	If ($args[0] -eq "external"){
		$objSearcher.ServerSelection = 2
	} else {
		$objSearcher.ServerSelection = 1
	}

	$objCollection = New-Object -ComObject "Microsoft.Update.UpdateColl"
	$objResults = $objSearcher.Search("IsInstalled=0")

	switch ($args[1]){
		"Critical" {$updates = $objResults.Updates | where {$_.MsrcSeverity -eq "Critical"}}
		"Important" {$updates = $objResults.Updates | where {("Important", "Critical") -contains $_.MsrcSeverity}}
		"Moderate" {$updates = $objResults.Updates | where {("Moderate", "Important", "Critical") -contains $_.MsrcSeverity}}
		"Low" {$updates = $objResults.Updates | where {("Low", "Moderate", "Important", "Critical") -contains $_.MsrcSeverity}}
		default {$updates = $objResults.Updates}
	}
	
	$output = ""

	foreach($Update in $updates){
		#$objCollectionTmp = New-Object -ComObject "Microsoft.Update.UpdateColl"
				
		if (($Update.title -notmatch "Language") `
			-and ($Update.title -notlike "Windows Internet Explorer * for Windows *") `
			-and ($Update.title -notlike "Internet Explorer * for Windows *") `
			-and ($Update.title -notlike "Service Pack * for Windows *") `
			-and ($Update.title -notmatch "Genuine"))
		{
			#$updateXml = convertTo-xml -inputObject $update -as string -notypeinformation
			#$updateXml.trimstart('<?xml version="1.0"?>')
			$output = $output + $Update.Title + "`n"
		}
	}
	return $output
}
$result = invoke-command -scriptblock $cmd -session $remoteWin.session -argumentlist $updateServer, $severity

if ($result -eq "") {
	writeCustomizedMsg ("Warn - find no update to install")
} else {
	$autoLogonScript = "powershell set-executionpolicy unrestricted; powershell c:\temp\updateWindows2.ps1 -updateServer $updateServer -severity $severity"
	if ($emailTo) {$autoLogonScript += " -emailTo $emailTo"}
	if ($uvsId) {$autoLogonScript += " -uvsId $uvsId"}
	$tempFileName = $serverAddress + "_" + $vmName + ".bat"
	$autoLogonScript | Set-Content .\$tempFileName

	$cmd = {
		$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
		new-itemproperty -path $regPath -name WinUpdate -value 'C:\temp\updateWindows.bat' -Confirm:$false -force
	}
	invoke-command -scriptblock $cmd -session $remoteWin.session

	$update_script = ".\windows\updateWindows2.ps1"
	$remoteWin.sendFile($update_script,"c:\temp\")
	$remoteWin.sendFile(".\$tempFileName","c:\temp\updateWindows.bat")
	remove-item ".\$tempFileName"
	$remoteWin.autoAdminLogon("local")
	writeCustomizedMsg ("Success - trigger Windows update task")
	writeCustomizedMsg ("Info - the following updates will be installed")
	writeStdout $result
}

If ($vm) {
	$floppy = Get-FloppyDrive -VM $vm.vivm
	Set-FloppyDrive -Floppy $floppy -NoMedia -Confirm:$False
	$cd = Get-CDDrive -VM $vm.vivm     
	Set-CDDrive -CD $cd -NoMedia -Confirm:$False
}