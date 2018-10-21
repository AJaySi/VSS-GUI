#############################################################
#
# TBD : Changes to accept user input for volume and its size for VSS setup. 
# The whole idea is to abstract using vssadmin or diskshadow utility.
# This powershell script can be extended to have a GUI as a wrapper on vssadmin, diskshadow and
# work both on windows servers and workstations. 
# TBD : Manage multiple remtoe servers, workstations.
# TBD : Target/destination folder to mounted volume shadow copies
# TBD : Path of volume shadow copies
#
#############################################################

if (Check-Isadmin)
{

	#Enable Shadows
	#vssadmin add shadowstorage /for=User_input /on=Ask_user Or default_seperate_volume /maxsize=User_input Or default to 10% of volume
	# For Demo purposes, hard code it for now.
	vssadmin add shadowstorage /for=D: /on=D:  /maxsize=10GB
	
	# (Get-ComputerInfo).OsProductType : isn't available prior to PowerShell v5.1
	# $wrkstat_or_server = Get-CimInstance -ClassName Win32_OperatingSystem
	# https://docs.microsoft.com/en-us/windows/desktop/CIMWin32Prov/win32-operatingsystem
	if (windows_server)
	{
		# VSS Create is only avialable on Windows server editions. Shadow Copy ID will test the creation as pass/fail.
		$string = vssadmin create shadow /for=C: | Select-String 'Shadow Copy ID','Shadow Copy Volume'
	} else 
	{
		# Windows workstations have WMI VSS class, which helps in creation of volume shadow copy.
		Write-Verbose "Creating a snapshot of $($ENV:SystemDrive)\"
		# get static method
		$class=[WMICLASS]"root\cimv2:win32_shadowcopy";

		"Creating a new shadow copy"
		$result = $class.create("$ENV:SystemDrive\", "ClientAccessible");
	}

	# Get existing shadow copies on the system. We can list to test if shadow copy was indeed created.
	# Use 'Shadow Copy ID','Shadow Copy Volume' to validate.
	$shadow_cp = get-wmiobject win32_shadowcopy
	"There are {0} VSS shadow copies on this sytem" -f $shadow_cp.count
  

	Action=new-scheduledtaskaction -execute "c:\windows\system32\vssadmin.exe" -Argument "create shadow /for=C:"
	$Trigger=new-scheduledtasktrigger -daily -at 6:00AM
	Register-ScheduledTask -TaskName ShadowCopyC_AM -Trigger $Trigger -Action $Action -Description "ShadowCopyC_AM"

}


# Helper Functions to check if VSS operations and running vssadmin is allowed.
Function Check-IsAdmin   
{  
<# 
    .SYNOPSIS
        Check if user is admin or elevated user to perform VSS operations. 
		Else fail and return error message.
     
    .DESCRIPTION
        VSS operations require adminstrative priviledges. If this is not the case then this script fails, rightly so.
             
	.EXAMPLE 
		Check-IsAdmin 
#>  
      
	Write-Verbose "Checking, if current user context is Administrator" 
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
    {
		"Error: Please run this script again with adminstrative priviledges"
        return $false
    }  
    Else   
    {
		"Running operation with adminstrative priviledges"
        return $true
    }  
}
