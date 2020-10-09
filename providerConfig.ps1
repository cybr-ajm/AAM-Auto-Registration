<#
Registers a new CP, or resets the credentials of an existing CP if the vault environment exists
Starts up CP service after the cred file is in sync with vault user
#>



###VARIABLES - UPDATE AS NEEDED TO REFLECT ACCURATE PATHS, ETC...###
$vaultIP = '10.0.0.10'
$vaultName = 'CompanyVault' #NO SPACES IN VAULT NAME
$adminCredFile = 'C:\Program Files (x86)\CyberArk\ApplicationPasswordProvider\Vault\admin.cred' #Assumes we have a pre-created admin cred file in our image
$vaultIniFile = 'C:\Program Files (x86)\CyberArk\ApplicationPasswordProvider\Vault\Vault.ini'
$pacliPath = 'C:\staging-build\scripts\PACLI\Pacli.exe'
$pacliScriptPath = 'C:\staging-build\scripts\PACLI\pacliScript.txt'
$hostname = hostname
$providerName = "Prov_$hostname"
$createEnvCommand = "C:\Program Files (x86)\CyberArk\ApplicationPasswordProvider\Env\CreateEnv.exe /Username $adminCredFile"
$providerCredLocation = '"C:\Program Files (x86)\CyberArk\ApplicationPasswordProvider\Vault\AppProviderUser.cred"'
$createCredFileCommand = "'C:\Program Files (x86)\CyberArk\ApplicationPasswordProvider\Vault\CreateCredFile.exe'"


Function Get-RandomAlphanumericString {
	
	[CmdletBinding()]
	Param (
        [int] $length = 8
	)

	Begin{
	}

	Process{
        Write-Output ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count $length  | % {[char]$_}) )
	}	
}

#Make sure CP Service is stopped
Stop-Service "CyberArk Application Password Provider"

#Config Vault.ini with correct Vault IP
(Get-Content -Path $vaultIniFile).replace('Address=1.1.1.1',"Address=$vaultIP") | Set-Content $vaultIniFile

#Run CreateEnv utility
#Invoke-Expression $createEnvCommand

#Generate new temporary provider password
$tempPassword = ""
do {
   $tempPassword = Get-RandomAlphanumericString(14)
} until ($tempPassword -match '\d')

#Create PACLI script File
$scriptContents = 
"define vault=$vaultName address=$vaultIP;
default vault=$vaultName user=Administrator safe=System;
LOGON LOGONFILE=`"$adminCredFile`";
UPDATEUSER VAULT=$vaultName DESTUSER=$providerName PASSWORD=$tempPassword;
logoff;
term;
"
Set-Content -Path $pacliScriptPath -Value $scriptContents

#Reset provider password in vault
Invoke-Expression "$pacliPath Init"
$pacliParams = "ExecuteFile file=$pacliScriptPath"
Invoke-Expression "$pacliPath $pacliParams"

#Create new provider cred file
$credFileCreateCmd = "& $createCredFileCommand $providerCredLocation Password /Username $providerName /Password $tempPassword"
Invoke-Expression $credFileCreateCmd -ErrorAction SilentlyContinue

#start CP service
Restart-Service -Name "CyberArk Application Password Provider"

#Add Cleanup Tasks Here -  Delete admin.cred, pacli script
