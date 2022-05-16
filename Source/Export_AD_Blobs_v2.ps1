<#
.SYNOPSIS
    On the AD Server side, offline ADJoin.
.DESCRIPTION
    This script will check for a DeviceList.txt file and if found will provision the listed devices to the domain of the server it is run on.
    If the DeviceList.txt file is not found, it will go through the process of creating the file and opening it for the user to enter device names into.
.EXAMPLE
    PS C:\> .\PATHTOFILE\ServerCreate.exe (Once Compiled)
    Running the script will open a GUI based environment to provision devices to domain.
.INPUTS
    C:\dir\DeviceList.txt
.OUTPUTS
    C:\dir\deviceNAME
.NOTES
    Version: 2.0
    Author: Jack Staples
#>

# Frameworks
Add-Type -AssemblyName PresentationFramework # Allows use of System.Windows.Messagebox

# Variables
$list = "C:\Temp\ADJoin\DeviceList.txt" # DeviceList.txt file location
$domain = (Get-WmiObject Win32_ComputerSystem).Domain # Domain
$ErrorActionPreference = "Stop"

# Display Text Box
function TextBox($message, $title, $buttons, $icon) {
    # Shortened function for textboxes
    $buttonstate = [System.Windows.Messagebox]::Show($message, $title, $buttons, $icon) # Display message box
    Return $buttonstate
}

# Provision Blob Function
function ProvisionBlob ($machine, $domain) {
    if (Test-Path "C:\Temp\ADJoin\$machine") {
        return $true
    }
    elseif (!(Test-Path "C:\Temp\ADJoin\$machine")) {
        # Djoin /provision /domain $domain /machine $machine /savefile "C:\Temp\ADJoin\$machine" /reuse
        
        # Test File Start
        New-Item "C:\Temp\ADJoin\$machine"
        (Write-Host "$machine") *>> "C:\Temp\ADJoin\$machine"
        # Test File End
        
        return $true
    }
    else {
        return $false
    }
}

# FTP Send Function
function FTPSend($machine) {
    # Config
    $Server = "ftp.workshop.andor.com.au"
    $Username = "ad.upload"
    $Password = "01000000d08c9ddf0115d1118c7a00c04fc297eb0100000016f7965a0c8d8340ac75a604ae0eb9860000000002000000000003660000c0000000100000000a8073db2c8507abaca42130a43ec9e10000000004800000a000000010000000101e2a42f2dae516d7ee0da20b0cce9d3800000062cb2f97d19994bc932a5e6f5baa69d306881bc332c697deaa115a95f0167e43ff3bc69086ea0adcb8d006088c6cc14df4a53c48e3c3c993140000001075e84a5aa17328237c4c3cdb2e9514b9d1b61b"
    $Password = ConvertTo-SecureString -String $Password

    # Files
    $LocalFile = "C:\Temp\ADJoin\$machine"
    $RemoteFile = "ftps://$Server/$machine"

    # Create FTP Rquest Object
    $FTPRequest = [System.Net.FtpWebRequest]::Create($RemoteFile)
    $FTPRequest = [System.Net.FtpWebRequest]$FTPRequest; $FTPRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
    $FTPRequest.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
    $FTPRequest.UseBinary = $true
    $FTPRequest.UsePassive = $true

    # Read the File for Upload
    $FileContent = Get-Content -AsByteStream $LocalFile
    $FTPRequest.ContentLength = $FileContent.Length
    
    try {
        $Run = $FTPRequest.GetRequestStream()
        try {
            $Run.Write($FileContent, 0, $FileContent.Length)
            try {
                # Cleanup
                $Run.Close()
                $Run.Dispose()
                return $true
            }
            catch {
                TextBox "Closing FTP connection failed." "FTP Close Failed" "Ok" "Error"
                return $false
            }
        }
        catch {
            TextBox "Failed to write file to FTP server." "FTP Write Failed" "Ok" "Error"
            return $false
        }
    }
    catch {
        TextBox "Failed to connect to FTP server." "FTP Connection Failed" "Ok" "Error"
        return $false
    }
    
    
}

& {
    # Dependencies Check
    if (!(Test-Path "C:\Temp\ADJoin\")) {
        New-Item "C:\Temp\ADJoin\" -ItemType Directory
    }

    if (Test-Path $list) {
        # Tests for DeviceList.txt file and provisions listed devices to domain if found
        foreach ($machine in Get-Content $list) {
            $Provisioned = ProvisionBlob $machine $domain
            if ($Provisioned) {
                TextBox "Provisioning has been completed." "Provisioning Complete" "Ok" "Info"
                $FTPSent = FTPSend $machine
                if ($FTPSent) {
                    TextBox "FTP upload has been completed." "FTP Upload Complete" "Ok" "Info"
                    Remove-Item "C:\Temp\ADJoin\" -Recurse
                }
                else {
                    TextBox "FTP upload has failed." "FTP Upload Failed" "Ok" "Error"
                }
            }
            else {
                TextBox "Provisioning failed." "Provisioning Failed" "Ok" "Error"
            }
        }
    }
    else {
        # Tests for DeviceList.txt and creates file if not found. Then provisions listed devices to domain
        New-Item -Path $list -ItemType File
        TextBox "Please enter device names line by line. Then save and close notepad to continue." "Instructions" "Ok" "Info"
        do {
            # Prompts for device names until user is ready to proceed
            notepad $list; $nid = (Get-Process notepad).Id; Wait-Process -Id $nid;
            $ready = TextBox "Are you ready to continue?" "Continue..." "YesNo" "Info" # Yes will provision devices, no will open notepad for editing $list
            switch ($ready) {
                "Yes" {
                    foreach ($machine in Get-Content $list) {
                        $Provisioned = ProvisionBlob $machine $domain
                        if ($Provisioned) {
                            TextBox "Provisioning has been completed." "Provisioning Complete" "Ok" "Info"
                            $FTPSent = FTPSend $machine
                            if ($FTPSent) {
                                TextBox "FTP upload has been completed." "FTP Upload Complete" "Ok" "Info"
                                
                            }
                            else {
                                TextBox "FTP upload has failed." "FTP Upload Failed" "Ok" "Error"
                            }
                        }
                        else {
                            TextBox "Provisioning failed." "Provisioning Failed" "Ok" "Error"
                        }
                    }
                }
            }
        } until ($ready -eq "Yes")
    }
} *>> "C:\Temp\ADJoinLog.txt"