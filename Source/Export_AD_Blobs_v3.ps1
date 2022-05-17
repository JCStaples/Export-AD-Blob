<#
.SYNOPSIS
    AD blob export utility for Active Directory Servers.
.DESCRIPTION
    This script will export an AD blob file for offline domain joining computers during the AIT imaging process.
    The exported blob files are transferred to the FTP server running on WDS001-NTL ready for utilisating by the imaging scripts.
.EXAMPLE
    PS C:\> .\PATHTOFILE\ServerCreate.exe (Once Compiled)
    Running the script will open a GUI based environment to provision devices to domain.
.INPUTS
    C:\Temp\ADJoin\DeviceList.txt
.OUTPUTS
    C:\Temp\ADJoin\$deviceName.blob
.NOTES
    Version: 3.0
    Author: Jack Staples
#>

# Global vars
$domainName = (Get-WmiObject Win32_ComputerSystem).domain
$ErrorActionPreference = "Stop"

# Functions

function messagePrompt($message, $title, $buttons, $icon) {
    # Shortened function for textboxes
    $buttonstate = [System.Windows.Messagebox]::Show($message, $title, $buttons, $icon) # Display message box
    Return $buttonstate
}

function createList($workPath, $listName) {
    if (!(Test-Path $workPath)) {
        New-Item -Path $workPath
    }
    Set-Location $workPath
    do {
        notepad $listName; $nId = (Get-Process notepad).Id; Wait-Process -Id $nId
        $continueScript = messagePrompt "Are you finished entering the computer names?" "Continue?" "YesNo" "Question"
    } until ($continueScript -eq "Yes")
}

function exportBlob($machineName, $domainName) {
    
}

# Main
$listCreated = createList "C:\Temp\ADJoin\" "DeviceList.txt"

if ($listCreated) {
    $blobExported = exportBlob "C:\Temp\ADJoin\" "DeviceList.txt"

    if ($blobExported) {
        $sentFTP = sendFTP "C:\Temp\ADJoin\"

        if ($sentFTP) {
            messagePrompt "AD blobs successfully exported." "Success!" "Ok" "info"
        }
    }
}