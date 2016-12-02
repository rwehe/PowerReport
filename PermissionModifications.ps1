<#
.SYNOPSIS
*This script has two primary functions. 
	- It will scan all subfolders of the target directory to generate a CSV report listing each user/group (IdentityReference), their NTFS Permissions on the file (FileSystemRights), and if that permission is Inherited or not (InheritedFlag). 
	- The second function of the script is to read in the CSV file and update (modify/remove) the users/groups permissions to reflect the CSV file.

.DESCRIPTION
*If you plan to run the script with the same target folder often, update the first variable ($Global:Path) to the path that you’ll primarily be targeting (not mandatory but recommend to save time).
*Change directory into the location where Folder_Permissions.csv is located or to the location that you’d like it to be created. The script will create a new CSV file in the location that you’ve run the script if there wasn’t one found.
*The script will first ensure that the target directory is valid. If the hard-coded path variable is not valid you will be prompted to set a correct target path.
*When a new CSV file gets created it will automatically open.

.NOTES
	File Name: PermissionModifications.ps1
	Author: Ryan Wehe – rwehe@asu.edu
	Organization: Arizona State University – ETS
.EXAMPLE
(CD into the location where Folder_Permissions.csv is located or to the location that you’d like it to be created.)
	.\<path to script>\PermissionModifications.ps1
#>

# Default directory to be scanned by the script
$Global:Path = "E:\Fulton"

If (Test-Path $Path){
	# The default path is valid
	$Global:PathDefault = $Path
}
Else{
	# The default path is not valid
	Write-Host "$Path is not a valid path" -ForegroundColor Red
	$Global:Path = $null
	$Global:PathDefault = "Invalid"
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

function comparePaths([string]$pathVariable,[string]$CSVfile){
	#Get directory path from the first path in the CSV file
	$CSVfilePath = (get-item (Import-Csv $CSVfile)[1].Path).parent.Fullname
	Clear-Host
	Write-Host "The current target differs from that referenced in $CSVfile." -BackgroundColor Yellow -ForegroundColor Red
	Write-Host "Current target:....... $pathVariable" -BackgroundColor White -ForegroundColor Blue
	Write-Host "Detected CSV target:.. $CSVfilePath" -BackgroundColor White -ForegroundColor Blue
	Do{
		Write-Host "Would you like to update the target path to $CSVfilePath ?" -BackgroundColor Black -ForegroundColor White
		$choice = Read-Host -Prompt "`nWould you like to update to the detected CSV target path: $CSVfilePath (Y/N)?"
		If ($choice -eq 'y'){
			$Global:path = $CSVfilePath
		}
		ElseIf ($choice -eq 'n'){
			Write-Host "Path remains $pathVariable"
		}
	}While($choice -ne 'y' -and $choice -ne 'n')
	Clear-Host
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
					Write-Host "Removing" $_.IdentityReference "from" $pathToModify -BackgroundColor DarkGray -ForegroundColor White
					RemoveNTFSPermissions $pathToModify $_.FileSystemRights $_.AccessControlType $_.IdentityReference $_.InheritanceFlags $_.PropagationFlags				
				 }
				}			
				AddNTFSPermissions $pathToModify $IdentityReference $FileSystemRights
				Write-Host "ACL Modified - Row:"$rowCount "| Path:" $pathToModify "| IdentityReference:" $IdentityReference "| FileSystemRights:" $FileSystemRights "| Access Control Type:" $accessControlType -BackgroundColor DarkGray -ForegroundColor White
				
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
	Write-Host "$flaggedrowCount flagged | $unflaggedrowCount not flagged | $removerowCount removed | " -NoNewline
	Write-Host "$errorCount errors" -ForegroundColor Red -NoNewline
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
#Loop back here if runStart -eq "y"
Do {
	Clear-Host	
	If ($Path -ne $null){
		If (Test-Path $Path){			
			#Loop back here if $invalid -eq "True"
			Do{
				If ($csvPath -ne $null){
					#Test if CSV target differs from the current target
					If($path -ne ((Get-Item (Import-Csv $csvPath)[1].Path).parent.Fullname)){comparePaths $path $csvPath}
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
						Clear-Host
						createPermissionsFile
						Invoke-Item -Path .\$Filename.csv
						$Global:invalid = "True"
					}
					ElseIf ($select -eq '2'){
						ModifyPermissions
						$Global:invalid = "False"
					}
					ElseIf ($select -eq '3'){
						Clear-Host
						Write-Host "The default target is $PathDefault"

						If (($Path -ne $PathDefault) -and ($PathDefault -ne "Invalid")){
							Write-Host "1) Set back to default`n2) New target"
							$decision = Read-Host -Prompt "1 or 2"
						}Else{$decision = 2}

						If($decision -eq '1'){
							$Global:Path = $PathDefault
							$Global:invalid = "False"
						}
						ElseIf($decision -eq '2'){
							Do{
								$newTarget = Read-Host -Prompt "`nEnter a new directory for script to target"
								If (!(Test-Path $newTarget)){Write-Host "$newTarget is not a valid path" -ForegroundColor Red}
								Else {
									$global:path = $newTarget
									$global:invalid = $true
									Clear-Host
								}
							}While(!(Test-Path $newTarget))						
						}
						Else{
							$Global:invalid = "True"
						}
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
					If ($newCSV -eq "Y"){
						createPermissionsFile
						$Global:csvPath = "$pwd" + "\" + "$filename" + ".csv"
						Invoke-Item -Path $csvPath
						$Global:invalid = "True"
					}
					Else{
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
	
			}
			Else{
				$global:path = $null
			}
	}
	Else{
		Clear-Host
		If ($PathDefault -eq "Invalid"){Write-Host "The default path you specified is not valid" -ForegroundColor Red}
		If ($path -eq $null){Write-Host "The target path is not set" -ForegroundColor Red}
		Else{Write-Host "$path is not a valid path" -ForegroundColor Red}
		Do{
			# Attempt to get a target from the current CSV
			If ($csvPath -ne $null){
				If(Test-Path $csvPath){
					$CSVfilePath = (get-item (Import-Csv $csvPath)[1].Path).parent.Fullname
					If (Test-Path $CSVfilePath){
						Write-Host "The path $CSVfilePath was detected."
						$newTarget = Read-Host -Prompt "`nEnter a new directory for script to target, or press 1 to set $CSVfilePath"
						If ($newTarget -eq '1'){
							$newTarget = $CSVfilePath
							$global:path = $CSVfilePath
						}
						Else{
							If (!(Test-Path $newTarget)){Write-Host "$newTarget is not a valid path" -ForegroundColor Red}
							Else {$global:path = $newTarget}
						}
					} # Test to the CSV's target failed
				} # Test to CSV file failed
			} # Failed due to null CSV Path
			Else{
				$newTarget = Read-Host -Prompt "`nEnter a new directory for script to target"
				If (!(Test-Path $newTarget)){Write-Host "$newTarget is not a valid path" -ForegroundColor Red}
				Else {$global:path = $newTarget}
			}
		}While(!(Test-Path $newTarget))	
		$global:runStart = "y"
	}	
}While ($runStart -eq "Y")
Clear-Host
EXIT

#####################################################################################################################################
#														Sources:
# SID_Query.ps1 by Brian Tancredi
#
# http://stackoverflow.com/questions/9725521/how-to-get-the-parents-parent-directory-in-powershell#9725667
#
# Add/remove NTFS Permissions Functions:
# http://stackoverflow.com/questions/11465074/powershell-remove-all-permissions-on-a-directory-for-all-users
#
# Creating Permissions File:
# http://stackoverflow.com/questions/35825648/list-all-folders-where-users-except-admin-have-allow-full-access
# ANSVLANReport.ps1 by Thomas Lewis
# https://phyllisinit.wordpress.com/2012/03/14/extracting-folder-and-subfolder-security-permission-properties-using-powershell/
#####################################################################################################################################