$compList = "C:\temp\computers.csv"
$reportLocation = "C:\Temp\powerTest.csv"

Import-Csv $compList |
    foreach{
        $system = "" | select `
        "Computer Name",`
        "Model",`
        "Serial Number",`
        "Energy Consumption (KWh)",`
        "Instantaneous Headroom (watts)",`
        "Peak Amperage Reading",`
        "Peak Headroom (watts)",`
        "Peak Power Reading (watts)",`
        "Peak Power Reading (BTU/hrs)",`
        "Power Supply Current Draw (amps) 1",`
        "Power Supply Current Draw (amps) 2"
        
        $chassis = (Get-WmiObject -ComputerName $_.Computer -Class "DELL_Chassis" -Namespace "ROOT\CIMV2\Dell")
        $PowerConsumptionData = (Get-WmiObject -ComputerName $_.Computer -Class "DELL_PowerConsumptionData" -Namespace "ROOT\CIMV2\Dell")
        $PowerConsumptionAmpsSensor = (Get-WmiObject -ComputerName $_.Computer -Class "DELL_PowerConsumptionAmpsSensor" -Namespace "ROOT\CIMV2\Dell")


        $system."Computer Name" = hostname
        $system.Model = $chassis.Model
        
        $system."Serial Number" = $chassis.SerialNumber
        $system."Energy Consumption (KWh)" = $PowerConsumptionData.cumulativePowerReading
        $system."Instantaneous Headroom (watts)" = $PowerConsumptionData.instHeadRoom
        $system."Peak Amperage Reading" = $PowerConsumptionData.peakAmpReading / 10
        $system."Peak Headroom (watts)" = $PowerConsumptionData.peakHeadRoom
        $system."Peak Power Reading (watts)" = $PowerConsumptionData.peakWattReading
        $system."Peak Power Reading (BTU/hrs)" = $PowerConsumptionData.peakWattReading * 3.412

        $system."Power Supply Current Draw (amps) 1" = ($PowerConsumptionAmpsSensor.CurrentReading  | Select -First 1) / 10
        $system."Power Supply Current Draw (amps) 2" = ($PowerConsumptionAmpsSensor.CurrentReading  | Select -Last 1) / 10

        $system
    } | Export-Csv $reportLocation