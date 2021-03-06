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

Param ($serverAddress, $serverUser="root", $serverPassword=$env:defaultPassword)

. .\objects.ps1

$server = newServer $serverAddress $serverUser $serverPassword
foreach ($vm in (Get-VM -server $server.viserver | sort))
{
	write-host "<vm>"
	write-host ("<name>" + $vm.name + "</name>")
	write-host ("<hostaddr>" + $vm.vmhost.name + "</hostaddr>")
	write-host ("<hostpassword>" + $serverPassword + "</hostpassword>")
	$path = $vm | get-view | %{$_.Config.Files.VmPathName}
	write-host ("<vmdkpath>" + $path + "</vmdkpath>")
	$ip = (Get-VMGuest $vm).IPAddress[0]
	write-host ("<ip>" + $ip + "</ip>")
	write-host "</vm>"
}