$computerName = $env:COMPUTERNAME

$fileLocation = "C:\Temp\remoteNames.txt"


try
{
    $namesFile = Get-Content $fileLocation -ErrorAction Stop
}
catch [System.Management.Automation.ItemNotFoundException]{
    Write-Host "Could not find a file located at $fileLocation`n" -BackgroundColor Black -ForegroundColor Red
}
catch{
    write-host "`n`nCaught an exception:" -ForegroundColor Red
    write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
}

if ($namesFile){
    $counter = 0
    $namesFile | %{
        $counter++
        try{
            Set-Variable -Name "computer$counter" -Value $_
        }
        catch {
            write-host "`n`nCaught an exception:" -ForegroundColor Red
            Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red -BackgroundColor Black
        }
    }
}