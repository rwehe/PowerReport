############################################################
#
# Ryan Wehe
# ASU FSE
# 11/10/2016
############################################################

# Default directory to be scanned by the script
$Global:Path = "E:\Fulton"

If (Test-Path $Path){
	# The default path is valid
	$Global:PathDefault = $Path
}
Else{
	# The default path is not valid
	Write-Host "$Path is not a valid path"
	$Global:Path = $null
	$Global:PathDefault = $null
}


If (Test-Path "Folder_Permissions.csv"){
	# Checks to see if there is a Folder_Permissions file in the directory from which the script was run, use by default if found.
	$global:csvPath = "$pwd"+"\Folder_Permissions.csv"
}
Else {$global:csvPath = $null}

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
	
	Import-Csv $csvPath |`
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
				Write-Host "ACL Modified - Row:"$rowCount "| Path:" $pathToModify "| IdentityReference:" $IdentityReference "| FileSystemRights:" $FileSystemRights "| Access Control Type:" $accessControlType -BackgroundColor White -ForegroundColor Cyan
				
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
			Write-Host "Removing" $_.IdentityReference "from" $_.Path -BackgroundColor White -ForegroundColor Cyan
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
	If (Test-Path $path){
		Write-Host "Analyzing:" $path -BackgroundColor Black -ForegroundColor DarkGreen

		# How many child folders do you want to scan?
		# 0 = Scan directorys only in the Path
		# 1 = Scan 1 layer, 2 = 2 layers, etc.
		$Depth = 0

		# To add datestamp to filename
		#$DS = Get-Date -Format MM-dd-yyyy

		# Build Filename
		$Global:Filename = "Folder_Permissions"

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
		Write-Host "Created file"$PWD"\"$Filename".csv" -BackgroundColor Black -ForegroundColor DarkGreen
	}
	Else{
		Write-Host "$path is not valid" -ForegroundColor Red
	}
}

#Prompt for user selection
#Loop back here if runAgain -eq "y"
Do {
	Clear-Host
	#Loop back here if $invalid -eq "True"
	Do{
		If ($csvPath -ne $null){
			Write-Host "`nThe current CSV file is: $csvPath" -ForegroundColor Black -BackgroundColor White
			Write-Host "The target path is: $Path" -ForegroundColor Black -BackgroundColor White
			Write-Host "`nSelect your inquiry..." -ForegroundColor Yellow
			Write-Host "`n1) Create a new CSV file" -ForegroundColor Green
			Write-Host "This option will overwrite the current CSV file with new permission data from: $path (Change this with option 3)`nThe CSV file will open after it has been created" -ForegroundColor Gray
			Write-Host "`n2) Modify permissions based on CSV file" -ForegroundColor Green
			Write-Host "This will check modify rows that have the flagged row set to TRUE or REMOVE" -ForegroundColor Gray
			Write-Host "`n3) Change the default target directory" -ForegroundColor Green
			Write-Host "This option allows you to change the target directory." -ForegroundColor Gray
			If ($Path -ne $PathDefault){Write-Host "The default value is $PathDefault and the current setting is $Global:Path" -ForegroundColor Gray}
			Else {Write-Host "Your current target path is set to the default: $Path" -ForegroundColor Gray}

			$select = Read-Host -Prompt "`nSelect 1, 2 or 3"
			
			If ($select -eq '1'){
				createPermissionsFile
				Invoke-Item -Path .\$Filename.csv
				$Global:invalid = "False"
			}
			ElseIf ($select -eq '2'){
				ModifyPermissions
				$Global:invalid = "False"
			}
			ElseIf ($select -eq '3'){
				Clear-Host
				Write-Host "The default target is $PathDefault"

				If (($Path -ne $PathDefault) -and ($PathDefault -ne $null)){
					Write-Host "1) Set back to default`n2) New target"
					$decision = Read-Host -Prompt "1 or 2"
				}Else{$decision = 2}

				If($decision -eq '1'){
					$Global:Path = $PathDefault
					$Global:invalid = "False"
				}
				ElseIf($decision -eq '2'){
					$newTarget = Read-Host -Prompt "`nEnter a new directory for script to target"
					If ((Test-Path $newTarget) -eq $true){
						$Global:Path = $newTarget
						$Global:invalid = "False"
					}
					Else{
						Write-Host "Path was not found!" -ForegroundColor Red
						$Global:invalid = "True"
					}
				}
				Else{$Global:invalid = "True"}
			}
			Else{
				#Invalid Selection
				Clear-Host
				Write-Host "`nInvalid Selection" -ForegroundColor Red -BackgroundColor Yellow
				$Global:invalid = "True"
				PAUSE
				Clear-Host
			}
		}
		Else {
			# Can't find CSV file
			Write-Host "`nCSV file can not be found" -ForegroundColor Red -BackgroundColor Yellow
			Write-Host "CSV would be created in" $pwd
			$newCSV = Read-Host "`nWould you like to create a new CSV file (Y,N)?"
			if ($newCSV -eq "Y"){
				createPermissionsFile
				$Global:csvPath = "$pwd" + "\" + "$filename" + ".csv"			
				$Global:invalid = "True"
			}
			else{
				$Global:invalid = "True"
				PAUSE
				Clear-Host
			}
		}
	
	}While ($invalid -eq "True")
	Write-Host `n
	PAUSE
	# Clear-Host
	# Prompt for Run Again
	$runStart = Read-Host "`nRun Again? From Start (Y,N)?"
}While ($runStart -eq "Y")
Clear-Host
EXIT

#####################################################################################################################################
#														Sources:
# Add/remove NTFS Permissions Functions:
# http://stackoverflow.com/questions/11465074/powershell-remove-all-permissions-on-a-directory-for-all-users
#
# Creating Permissions File:
# http://stackoverflow.com/questions/35825648/list-all-folders-where-users-except-admin-have-allow-full-access
# ANSVLANReport.ps1 by Thomas Lewis
# SID_Query.ps1 by Brian Tancredi
# https://phyllisinit.wordpress.com/2012/03/14/extracting-folder-and-subfolder-security-permission-properties-using-powershell/
#####################################################################################################################################