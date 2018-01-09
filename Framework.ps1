<#
  This is the file to get started with the framework.
#>

#Requires -version 5.0;
Write-Output "I'm version 5.0 or above";

#Start GLOBAL Params

#.NET Dependancies
Add-Type -AssemblyName System.DirectoryServices;
Add-Type -AssemblyName System.DirectoryServices.AccountManagement;

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
$DomainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().name;
$PrincipleContext = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext(1,$DomainName);
$defaultOU = [regex]::Match((Get-ADUser $UserName).distinguishedName, '(?=OU)(.*\n?)(?<=.)').value;
$defaultDomain = [regex]::Match((Get-ADUser $UserName).distinguishedName, '(?=DC)(.*\n?)(?<=.)').value;

#Constants
$keyFile = "$foldersMyDocuments\AES.key"
$passwordFile = "$foldersMyDocuments\password.txt"

#End GLOBAL Params

#Start FUNCTIONS

function updateManager
{
  #Convert to use .NET vs AD module
	<#
		.SYNOPSIS
		function to update manager in AD
		.DESCRIPTION
		This function will update the manager of anyone in the Supervisor_Change.txt file located in My Documents.  It uses first and last name and gets samAccountName.
		.PARAMETER manager
		The manager you will be changeing to
		.PARAMETER file
		The file you will use to update multiple users manager
	#>
	
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$TRUE,HelpMessage='What is the name of the manager you are changing to?')][String()]$managerName,
		[Parameter(Mandatory=$TRUE,HelpMessage='What is the name of the file you are going to use?')][String()]$file
	)

	#$file = "$foldersMyDocuments\supervisor_change.txt"
	$NameList = Get-Content $file

	foreach ($Name in $NameList){
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

function CreateUser
{
	<#
		.SYNOPSIS
		function to create a user account
		.DESCRIPTION
		This function is used to create a new user account in AD.
		.PARAMETER fullUserName
		The full name of the user
		.PARAMETER Type
		What type of samAccountName is it, first.last or first inital and last name.  You can use initallastname, iln, firstnamelastname, fnln, firstnamedotlastname, fndln, lastnameinitial, lni.
		.PARAMETER Template
		Are you using a template account to copy from?
	#>
	
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$TRUE,HelpMessage='What is the full name of the user?')][String]$fullUserName,
        [Parameter(Mandatory=$TRUE,HelpMessage='What type of samAccountName?')][String]$type,
		[Parameter(Mandatory=$FALSE,HelpMessage='Will this be based off a template or no?')][Bool]$Template
	)

    [String]${FirstName}, [String]${LastName} = $fullUserName.split(" ");
    [String]$FirstInitial = $FirstName.Substring(0,1).ToLower();

    [String]$FirstName = (Get-Culture).TextInfo.ToTitleCase($FirstName);
    [String]$LastName = (Get-Culture).TextInfo.ToTitleCase($LastName);

    $Key = Get-Content $keyFile
    $Password = Get-Content $PasswordFile | ConvertTo-SecureString -Key $key

		
	switch ($type)
	{
		{$_ -in "initallastname","iln"} {$samAccountName = "$FirstInitial$LastName"};
		{$_ -in "firstnamelastname","fnln"} {$samAccountName = "$FirstName$LastName"};
        {$_ -in "firstnamedotlastname","fndln"} {$samAccountName = "$FirstName.$LastName"};
		{$_ -in "lastnameinital","lni"} {$samAccountName = "$Lastname$FirstInitial"};
	}
	
    Try
    {
		$samAccountName = $samAccountName.SubString(0,20).ToLower();
    }
    catch
    {
        $samAccountName = $samAccountName.ToLower();
    }

	$userPrincipalName = "$samAccountName@$DomainName"
	
	if($Template)
    {
		$TemplateAccount = Get-ADUser -Identity "templateaccount";
		New-ADUser -Instance $TemplateAccount -SamAccountName $samAccountName;			
	}
	else
	{
		New-ADUser -Name $fullUserName -GivenName $FirstName -Surname $LastName -samAccountName $samAccountName -UserPrincipalName $userPrincipalName -AccountPassword $Password -PassThru | Enable-ADAccount
	}
}

Function createKeyFile
{
    $Key = Byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
    $Key | out-file $KeyFile
}

Function createPasswordFile
{
    $Key = Get-Content $keyFile
    $Password = "Temppassword1$" | ConvertTo-SecureString -AsPlainText -Force
    $Password | ConvertFrom-SecureString -Key $Key | Out-File $passwordFile
}

#End FUNCTIONS

#$user = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($PrincipleContext, "a_valid_samaccountname")
#$user = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($PrincipleContext, "mmeyers")

Class createuser
{
    [ValidatePattern("^[a-z]+$")]
    [String]$FirstName
    [ValidatePattern("^[a-z]+$")]
    [String]$LastName
    hidden [string]$UserName
    [ValidateSet('Onsite','Offsite')]
    [string]$EmployeeLocation
    [ValidatePattern("^OU=")]
    [String]$OU = $defaultOU
    hidden static [String]$Domain = $defaultDomain
        
    [string]SamAccountName([string]$FirstName,[string]$LastName){
        
        $UName = ($FirstName.Substring(0,1) + $LastName).ToLower()

        $AllNames = Get-ADUser -Filter "SamaccountName -like '$UName*'"

        if($AllNames){
            [int16]$Count = $AllNames.distinguishedname.count

            if($count > 0){
                [int]$Advance = $Count++


            }
        }else{
            
        }

        return $this.SamAccountName
    }
   
    
    createuser(){
    }

    createuser ([string]$FirstName,[string]$LastName,[string]$EmployeeLocation){
        $UserOU = ""

        $this.EmployeeLocation = $EmployeeLocation
        $this.FirstName = $FirstName
        $this.LastName = $LastName
        $this.UserName = [createuser]::SamAccountName($FirstName,$LastName)

    }


    [createuser]Create(){
        New-ADUser -SamAccountName $this.UserName -GivenName $this.FirstName -Surname $this.LastName -UserPrincipalName $this.UserName -DisplayName ("$this.FirstName $this.LastName") -Path $this.OU

        return $this
    }
}
