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
		.PARAMETER file
		The file you will use to update multiple users manager
	#>
	
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$True,HelpMessage='What is the name of the manager you are changing to?')][String()]$managerName
		[Parameter(Mandatory=$True,HelpMessage='What is the name of the file you are going to use?')][String()]$file
	)

	#$file = "$foldersMyDocuments\supervisor_change.txt"
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

Function CreateUser
{
	<#
		.SYNOPSIS
		Function to create a user account
		.DESCRIPTION
		This function is used to create a new user account in AD.
		.PARAMETER Name
		The full name of the user
	#>
	
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$True,HelpMessage='What is the full name of the user?')][String()]$fullUserName
	)

		Function createSAMAccountName
		{
			#steps to create username for environment
			
			<#
				.SYNOPSIS
				Function to formulate the samaccountname of an account.
				.DESCRIPTION
				Function used to forumulate a samaccountname for the environment.
				.PARAMETER NameInput
				The full name of the user
				.PARAMETER Type
				What type of samaccountname is it, first.last or first inital and last name.  You can use initallastname, iln, firstnamelastname, fln.
			#>
			
			[CmdletBinding()]
			param(
				[Parameter(Mandatory=$True,HelpMessage='What is the name of the person?')][String()]$NameInput,
				[Parameter(Mandatory=$True,HelpMessage='What is the type of samaccountname is it, first.last or first inital and last name?')][String()]$Type
			)
				
			Function initallastname
			{
				$FirstInitial =  $NameInput.split(" ")[0].Substring(0,1).ToLower();
				$LastName = $NameInput.split(" ")[1].ToLower();
				
				$OutputName = ("{0}{1}" -f $FirstInitial,$LastName).ToLower();
				
				return $outputName;
			}
			
			Function firstnamelastname
			{
				$OutputName = ($NameInput.replace(" ",".")).ToLower();
				
				return $outputName;
			}
			
			switch ($type)
			{
				{$_ -in "initallastname","iln"} {$samaccountname = initallastname};
				{$_ -in "firstnamelastname","fln"} {$samaccountname = firstnamelastname};
			}
			
			return $samaccountname;
		}
	
	
}
#End FUNCTIONS

#$user = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($context, "a_valid_samaccountname")
