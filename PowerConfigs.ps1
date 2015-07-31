$fileLocation = "C:\Temp\remoteNames.txt"
$reportLocation = "C:\Temp\powerTest.csv"


function reportPowerInformation{
#    Param (
#        [string]$computerName
#    )
    $computerName = $env:COMPUTERNAME

    $objects = [ordered]@{
        "Computer Name" = hostname
        # The following commands use Class "DELL_Chassis" and Namespace "ROOT\CIMV2\Dell"
        "Model" = (Get-WmiObject -Class "DELL_Chassis" -ComputerName $computerName -Namespace "ROOT\CIMV2\Dell").Model
        "Serial Number" = (Get-WmiObject -Class "DELL_Chassis" -ComputerName $computerName -Namespace "ROOT\CIMV2\Dell").SerialNumber    


        # The following commands use Class "DELL_PowerConsumptionData" and Namespace "ROOT\CIMV2\Dell"
        "Energy Consumption (KWh)" = (Get-WmiObject -Class "DELL_PowerConsumptionData" -ComputerName $computerName -Namespace "ROOT\CIMV2\Dell").cumulativePowerReading
        "Instantaneous Headroom (watts)" = (Get-WmiObject -Class "DELL_PowerConsumptionData" -ComputerName $computerName -Namespace "ROOT\CIMV2\Dell").instHeadRoom
        "Peak Amperage Reading" = (Get-WmiObject -Class "DELL_PowerConsumptionData" -ComputerName $computerName -Namespace "ROOT\CIMV2\Dell").peakAmpReading / 10
        "Peak Headroom (watts)" = (Get-WmiObject -Class "DELL_PowerConsumptionData" -ComputerName $computerName -Namespace "ROOT\CIMV2\Dell").peakHeadRoom
        "Peak Power Reading (watts)" = (Get-WmiObject -Class "DELL_PowerConsumptionData" -ComputerName $computerName -Namespace "ROOT\CIMV2\Dell").peakWattReading
        "Peak Power Reading (BTU/hrs)" = [math]::Round((Get-WmiObject -Class "DELL_PowerConsumptionData" -ComputerName $computerName -Namespace "ROOT\CIMV2\Dell").peakWattReading * 3.412, 2)

        # The following commands use Class "DELL_PowerConsumptionAmpsSensor" and Namespace "ROOT\CIMV2\Dell"
        "Power Supply Current Draw (amps)" = (Get-WmiObject -Class "DELL_PowerConsumptionAmpsSensor" -ComputerName $computerName -Namespace "ROOT\CIMV2\Dell").CurrentReading / 10
        

    } | %{New-Object psobject -Property $_}
    return $objects
}

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

#if ($namesFile){
#    $counter = 0
#
#    foreach ($name in $namesFile){
#        reportPowerInformation($name) | Export-Csv $reportLocation -NoTypeInformation -Force
#    }

#    $namesFile | %{
#        $counter++
#        try{
#            Set-Variable -Name "computer$counter" -Value $_
#
#            New-Object PSObject
#
#        }
#        catch {
#            Write-Host "`n`nCaught an exception:" -ForegroundColor Red
#            Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red -BackgroundColor Black
#        }
#    }
#}

function generateReport{
    # Variable for file location
    #$FileLocation = "C:\powertest.csv"
    reportPowerInformation | Export-Csv $reportLocation
}
generateReport
