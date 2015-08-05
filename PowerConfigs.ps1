$hostsPath = "C:\Temp\computers.csv" # Set this variable to point to the location of the CSV file with the hostnames
$Global:reportLocation = "C:\Power Report.csv" # Set this variable to point to the location of the ouput of this script


function Get-PowerReport{
    param(
        [string]$computerName
    )

    Write-Host "working on: $computerName" -ForegroundColor Green -BackgroundColor Black

    $system = "" | select `
    "Computer Name",`
    "Model",`
    "Operating System",`
    "Serial Number",`
    "Energy Consumption (KWh)",`
    "Instantaneous Headroom (watts)",`
    "Peak Amperage Reading",`
    "Peak Headroom (watts)",`
    "Peak Power Reading (watts)",`
    "Peak Power Reading (BTU/hrs)",`
    "Power Supply Current Draw (amps) 1",`
    "Power Supply Current Draw (amps) 2" 

    if (Test-Connection $computerName -ErrorAction SilentlyContinue){ # Pings the host to verify reply
        try{
            $chassis = (Get-WmiObject -ComputerName $computerName -Class "DELL_Chassis" -Namespace "ROOT\CIMV2\Dell" -ErrorAction SilentlyContinue -ErrorVariable e)
            $PowerConsumptionData = (Get-WmiObject -ComputerName $computerName -Class "DELL_PowerConsumptionData" -Namespace "ROOT\CIMV2\Dell" -EA SilentlyContinue)
            $PowerConsumptionAmpsSensor = (Get-WmiObject -ComputerName $computerName -Class "DELL_PowerConsumptionAmpsSensor" -Namespace "ROOT\CIMV2\Dell" -EA SilentlyContinue)

        }
        catch [System.Management.ManagementException]{
            Write-Host "System management exception`nInvalid namespace suspected"
            $system."Computer Name" = "Attempted: $computerName"
            $system.Model = "Invalid namespace suspected"
        }
        catch [System.UnauthorizedAccessException]{
            Write-Host "Unauthorized Access Exception" -BackgroundColor Black -ForegroundColor Red
            Write-Host "Did you use your 'a' account?" -BackgroundColor Black -ForegroundColor Yellow
        }

#      Generic information about each machine that will report regardless
#            $system."Computer Name" = (Get-WmiObject -ComputerName $computerName -Class Win32_ComputerSystem).Name
#        I decided to change the computer name property to what was passed to the function instead of a query to the system's hostname (old line above)
            $system."Computer Name" = $computerName
            $OS = ((Get-WmiObject -ComputerName $computerName Win32_OperatingSystem).Name)
    # The OS variable set above includes the full install path which isn't needed in this case
            $system."Operating System" = $OS.Substring(0,($OS.IndexOf("|"))) # Grabs the content before the | in the string

        # 3 'if' statments, each will only run if the server has the class and the namespace
        if($chassis){
            $system.Model = $chassis.Model
            $system."Serial Number" = $chassis.SerialNumber
        } else {Write-Host "DELL_Chassis failed for $computerName" -ForegroundColor Red -BackgroundColor Gray}
        if($PowerConsumptionData){
            $system."Energy Consumption (KWh)" = $PowerConsumptionData.cumulativePowerReading
            $system."Instantaneous Headroom (watts)" = $PowerConsumptionData.instHeadRoom
            $system."Peak Amperage Reading" = $PowerConsumptionData.peakAmpReading / 10
            $system."Peak Headroom (watts)" = $PowerConsumptionData.peakHeadRoom
            $system."Peak Power Reading (watts)" = $PowerConsumptionData.peakWattReading
            $system."Peak Power Reading (BTU/hrs)" = $PowerConsumptionData.peakWattReading * 3.412
        } else {Write-Host "DELL_PowerConsumptionData failed for $computerName" -ForegroundColor Red -BackgroundColor Gray}
        if($PowerConsumptionAmpsSensor){
            $system."Power Supply Current Draw (amps) 1" = ($PowerConsumptionAmpsSensor.CurrentReading  | Select -First 1) / 10
            $system."Power Supply Current Draw (amps) 2" = ($PowerConsumptionAmpsSensor.CurrentReading  | Select -Last 1) / 10            
        } else {Write-Host "DELL_PowerConsumptionAmpsSensor failed for $computerName" -ForegroundColor Red -BackgroundColor Gray}
    }
    else{
    # Connection to the host failed
        $system."Computer Name" = "Attempted: $computerName"
        $system."Model" = "Echo request packet failed"
        Write-Host "Ping to $computerName failed" -ForegroundColor Red
    }

    $system | Export-Csv $Global:reportLocation -Append
    }

# Attempts to read a CSV file located at $hostsPath
try{
    $hostsList = Import-Csv $hostsPath -Header Computer -EA SilentlyContinue -ErrorVariable e
}
catch [System.IO.FileNotFoundException]{
    Write-Host "File located at: $hostsPath was not found`n" -BackgroundColor Black -ForegroundColor Red
    Write-Host "Error was`n$e"
}

# If-Else to loop through the csv file and run each entry through the Get-PowerReport function
if($hostsList){
    Write-Host "Reporting to $Global:reportLocation" -BackgroundColor Black -ForegroundColor DarkGreen
    Import-Csv $hostsPath | ForEach-Object{
        Get-PowerReport -computerName ($_.Computer)
    }
}
else{
    Write-Host "All failed" -ForegroundColor Red -BackgroundColor Black
}