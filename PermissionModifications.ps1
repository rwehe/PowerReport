#############################################################
# Set $Path to the directory to scan
#
# Ryan Wehe
# ASU FSE
# 11/10/2016
#############################################################

# This variable sets which CSV file the script reads

$filepath = "E:\Users\rwehe\Documents\PowerShell\Folder_Permissions.csv"

function RemoveNTFSPermissions($path, $permission, $accesstype, $object, $inhflag, $propflag ) {
    $FileSystemRights = [System.Security.AccessControl.FileSystemRights]$permission
    $AccessControlType =[System.Security.AccessControl.AccessControlType]::$accesstype
	$InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]$inhflag
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]$propflag	
    $Account = New-Object System.Security.Principal.NTAccount($object)
    $FileSystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Account, $FileSystemRights, $InheritanceFlag, $PropagationFlag, $AccessControlType)
    $DirectorySecurity = Get-ACL $path
    $DirectorySecurity.RemoveAccessRuleAll($FileSystemAccessRule)
    Set-ACL $path -AclObject $DirectorySecurity
}

function RemoveNTFSPermissionsBasic($path, $object, $permission) {
    $FileSystemRights = [System.Security.AccessControl.FileSystemRights]$permission
    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]"None"
    $AccessControlType =[System.Security.AccessControl.AccessControlType]::Allow
    $Account = New-Object System.Security.Principal.NTAccount($object)
    $FileSystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Account, $FileSystemRights, $InheritanceFlag, $PropagationFlag, $AccessControlType)
    $DirectorySecurity = Get-ACL $path
    $DirectorySecurity.RemoveAccessRuleAll($FileSystemAccessRule)
    Set-ACL $path -AclObject $DirectorySecurity
}

function AddNTFSPermissions($path, $object, $permission) {
    $FileSystemRights = [System.Security.AccessControl.FileSystemRights]$permission
	$InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]"None"
    $AccessControlType =[System.Security.AccessControl.AccessControlType]::Allow
    $Account = New-Object System.Security.Principal.NTAccount($object)
    $FileSystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Account, $FileSystemRights, $InheritanceFlag, $PropagationFlag, $AccessControlType)
    $DirectorySecurity = Get-ACL $path
    $DirectorySecurity.AddAccessRule($FileSystemAccessRule)
    Set-ACL $path -AclObject $DirectorySecurity
}

function ModifyPermissions{
	$rowCount = 1 # Starts at 1 due to headers line
	$flaggedrowCount = 0
	$unflaggedrowCount = 0
	$removerowCount = 0
	$errorCount = 0
	
	Import-Csv $filepath |`
	ForEach-Object {
		$rowCount = ($rowCount+1)
		# Checks the Flagged value for True
		If ($_.Flagged -eq $true){
			# Validate the FileSystemRights column for an accurate value of:
			# FullControl; Modify, Synchronize; Read, Synchronize; ReadAndExecute, Synchronize; Write, Synchronize; Write, ReadAndExecute, Synchronize			
			If ($_.FileSystemRights -eq "FullControl" -or $_.FileSystemRights -eq "Modify, Synchronize" -or $_.FileSystemRights -eq "Read, Synchronize" -or $_.FileSystemRights -eq "ReadAndExecute, Synchronize" -or $_.FileSystemRights -eq "Write, Synchronize" -or $_.FileSystemRights -eq "Write, ReadAndExecute, Synchronize"){
				# Sets a variable for the folder path in the flagged line
				$pathToModify = $_.Path
				# Grab current ACL of the flagged line
				$tempACL = Get-ACL $_.Path
				# Put proposed changes into variables
				$IdentityReference = $_.IdentityReference
				$FileSystemRights = $_.FileSystemRights
				
				$tempACL | Select -ExpandProperty Access | 
				
				%{if ($_.IdentityReference -eq $IdentityReference){
					Write-Host "Removing" $_.IdentityReference "from" $pathToModify -BackgroundColor Red -ForegroundColor Black
					RemoveNTFSPermissions $pathToModify $_.FileSystemRights $_.AccessControlType $_.IdentityReference $_.InheritanceFlags $_.PropagationFlags				
				 }
				}			
				AddNTFSPermissions $pathToModify $IdentityReference $FileSystemRights
				Write-Host "ACL Modified - Row:"$rowCount "| Path:" $pathToModify "| IdentityReference:" $IdentityReference "| FileSystemRights:" $FileSystemRights "| Access Control Type:" $accessControlType -BackgroundColor White -ForegroundColor Red
				
				$flaggedrowCount = ($flaggedrowCount+1)
			}
			Else{
				Write-Host "Invalid access detected on row"$rowCount -BackgroundColor Red -ForegroundColor Black
				$errorCount = ($errorCount+1)
			}
		}
#		Checks the Flagged value for remove
		If ($_.Flagged -eq "remove"){
			RemoveNTFSPermissionsBasic $_.Path $_.IdentityReference $_.FileSystemRights			
			Write-Host "Removing" $_.IdentityReference "from" $_.Path -BackgroundColor Red -ForegroundColor Black
			$removerowCount = ($removerowCount+1)
		}
		Else{
			#Write-Host "No flagged rows found" -BackgroundColor DarkGreen -ForegroundColor Black
			$unflaggedrowCount = ($unflaggedrowCount+1)
		}
	}
	Write-Host $flaggedrowCount "flagged |" $unflaggedrowCount "not flagged |" $removerowCount "removed |" $errorCount "errors"
}

function createPermissionsFile{
	# Path to scan
	$Path = "E:\Fulton"

	# How many child folders do you want to scan?
	# 0 = Scan directorys only in the Path
	# 1 = Scan 1 layer, 2 = 2 layers, etc.
	$Depth = 0

	# To add datestamp to filename
	#$DS = Get-Date -Format MM-dd-yyyy

	# Build Filename
	$Filename = "Folder_Permissions"

	Get-ChildItem $Path -Directory | ForEach-Object {
		$file = $_
		
		Get-Acl -Path $file.FullName |
		Select-Object -ExpandProperty Access |
		
		ForEach-Object {
			#ForEach ACL
			New-object psobject -Property @{
				Path = $file.FullName
				IdentityReference = $_.IdentityReference
				FileSystemRights = $_.FileSystemRights
				#AccessControlType = $_.AccessControlType
				Flagged = $false
				InheritedFlag = $_.IsInherited
			}
		}
	} | Select-Object -Property Path, IdentityReference, FileSystemRights, Flagged, InheritedFlag | Export-Csv -Path .\$Filename.csv -NoTypeInformation
	Write-Host "Created file "$PWD"\"$Filename".csv" -ForegroundColor DarkGreen
}

#####################################################################################################################################
#														Sources:
# Add/remove NTFS Permissions Functions:
# http://stackoverflow.com/questions/11465074/powershell-remove-all-permissions-on-a-directory-for-all-users
#
# Creating Permissions File:
# http://stackoverflow.com/questions/35825648/list-all-folders-where-users-except-admin-have-allow-full-access
# ANSVLANReport.ps1 by Thomas Lewis
# https://phyllisinit.wordpress.com/2012/03/14/extracting-folder-and-subfolder-security-permission-properties-using-powershell/
#####################################################################################################################################