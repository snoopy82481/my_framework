<#
  This is the file to get started with the framework.
#>

#Requires -version 3.0;
Write-Output "I'm version 3.0 or above";

#Start GLOBAL Params

#.NET Dependancies
[System.Reflection.Assembly]::LoadWithPartialName("System.DirectoryServices")
[System.Reflection.Assembly]::LoadWithPartialName("System.DirectoryServices.AccountManagement")

#Imports
Import-Module ActiveDirectory

#Special Folders
$foldersMyDocuments = [Environment]::GetFolderPath("MyDocuments");
$foldersDesktop = [Environment]::GetFolderPath("Desktop");
$foldersAppDataRoaming = [Environment]::GetFolderPath("ApplicationData");
$foldersAppDataLocal = [Environment]::GetFolderPath("LocalApplicationData");
$foldersFavorites = [Environment]::GetFolderPath("Favorites");
$foldersSystem = [Environment]::GetFolderPath("System");
$foldersProgramFiles = [Environment]::GetFolderPath("ProgramFiles");
$foldersProgramFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86");

#User/Computer information
[String]${UserDomain},[String]${UserName} = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.split("\");
$localHostName = [System.Net.Dns]::GetHostEntry("localhost").HostName;
$RidMaster = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).RidRoleOwner.name;
$DomainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().name
$PrincipleContext = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext(1,$DomainName)

#End GLOBAL Params

#Start FUNCTIONS

Function updateManager {
  #Convert to use .NET vs AD module
	<#
		.SYNOPSIS
		Function to update manager in AD
		.DESCRIPTION
		This function will update the manager of anyone in the Supervisor_Change.txt file located in My Documents.  It uses first and last name and gets samAccountName.
		.PARAMETER manager
		The manager you will be changeing to
	#>
	
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$True,HelpMessage='What is the name of the manager you are changing to?')][String()]$managerName
	)

	$file = "$foldersMyDocuments\supervisor_change.txt"
	$NameList = Get-Content $file

	Foreach ($Name in $NameList){
		$Namecount = $Name.split(" ").count
		$userFirstName = $Name.split(" ")[0];
		$managerFirstName = $managerName.split(" ")[0];
		
		if($Namecount -eq 2){
			$userLastName = $Name.split(" ")[1];
		}else{
			$userLastName = $Name.split(" ")[1] + " " + $Name.split(" ")[2];
		}
		
		if($managerNameCount -eq 2){
			$managerLastName = $managerName.split(" ")[1];
		}else{
			$managerLastName = $managerName.split(" ")[1] + " " + $managerName.split(" ")[2];
		}
		
		$samAccountName = (Get-ADUser -filter {(GivenName -like $userFirstName) -and (Surname -like $userLastName)}).samaccountname;
		$managerSamAccountName = (Get-ADUser -filter {(GivenName -like $managerFirstName) -and (Surname -like $managerLastName)}).samaccountname;
		
		Set-ADUser -Identity $samAccountName -Manager $managerSamAccountName;
		
		$managerDetails = Get-ADUser (Get-ADUser $samAccountName -properties manager).manager -properties displayName;
		
		if($managerDetails.displayName -ne $managerName){
			Write-Host $Name manager was not able to be changed;
		}else{
			Write-host $Name manager updated to $manager;
		}
	}
}

#End FUNCTIONS

#$user = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($context, "a_valid_samaccountname")
