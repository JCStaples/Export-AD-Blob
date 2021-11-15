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

<#Frameworks#>
Add-Type -AssemblyName PresentationFramework #Allows use of System.Windows.Messagebox

<#Variables#>
$list = "C:\Temp\ADJoin\DeviceList.txt" #DeviceList.txt file location
$domain = (Get-WmiObject Win32_ComputerSystem).Domain #Domain
$FTPServer = "27.33.253.184"
$FTPServerUN = "ad.upload"
$FTPServerPW = "62002600650075002500730078003200210039005e00470032006e0043002100740021004800680044004d0036002100"
$FTPServerPW = ConvertTo-SecureString $FTPServerPW
$ErrorActionPreference = "Stop"

<#Display Text Box#>
function TextBox($message, $title, $buttons, $icon) {
    #Shortened function for textboxes
    $buttonstate = [System.Windows.Messagebox]::Show($message, $title, $buttons, $icon) #Display message box
    Return $buttonstate
}

<#Provision Blob Function#>
function ProvisionBlob ($machine, $domain) {
    if (Test-Path "C:\Temp\ADJoin\$machine") {
        return $true
    }
    elseif (!(Test-Path "C:\Temp\ADJoin\$machine")) {
        Djoin /provision /domain $domain /machine $machine /savefile "C:\Temp\ADJoin\$machine" /reuse
        return $true
    }
    else {
        return $false
    }
}

<#FTP Send Function#>
function FTPSend($machine, $FTPServer, $Username, [SecureString] $Password) {
    #Files
    $LocalFile = "C:\Temp\ADJoin\$machine"
    $RemoteFile = "ftp://$hostname/$machine"

    #Create FTP Rquest Object
    $FTPRequest = [System.Net.FtpWebRequest]::Create("$RemoteFile")
    $FTPRequest = [System.Net.FtpWebRequest]$FTPRequest; $FTPRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
    $FTPRequest.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
    $FTPRequest.UseBinary = $true
    $FTPRequest.UsePassive = $true

    #Read the File for Upload
    $FileContent = Get-Content -en byte $LocalFile
    $FTPRequest.ContentLength = $FileContent.Length
    
    try {
        $Run = $FTPRequest.GetRequestStream()
        try {
            $Run.Write($FileContent, 0, $FileContent.Length)
            try {
                #Cleanup
                $Run.Close()
                $Run.Dispose()
                return $true
            }
            catch {
                Write-Error -Message "Closing FTP connection failed."
                return $false
            }
        }
        catch {
            Write-Error -Message "Failed to write file to FTP server."
            return $false
        }
    }
    catch {
        Write-Error -Message "Failed to connect to FTP server."
        return $false
    }
    
    
}

& {
    <#Dependencies Check#>
    if (!(Test-Path "C:\Temp\ADJoin\")) {
        New-Item $dir -ItemType Directory
    }

    if (Test-Path $list) {
        #Tests for DeviceList.txt file and provisions listed devices to domain if found
        foreach ($machine in Get-Content $list) {
            $Provisioned = ProvisionBlob($machine, $domain)
            if ($Provisioned) {
                TextBox "Provisioning has been completed." "Provisioning Complete" "Ok" "Info"
                $FTPSent = FTPSend($machine, $FTPServer, $FTPServerUN, $FTPServerPW)
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
        #Tests for DeviceList.txt and creates file if not found. Then provisions listed devices to domain
        New-Item -Path $list -ItemType File
        TextBox "Please enter device names line by line. Then save and close notepad to continue." "Instructions" "Ok" "Info"
        do {
            #Enter loop until condition on ln 155.
            notepad $list; $nid = (Get-Process notepad).Id; Wait-Process -Id $nid;
            $ready = TextBox "Are you ready to continue?" "Continue..." "YesNo" "Info" #Yes will provision devices, no will open notepad for editing $list
            switch ($ready) {
                "Yes" {
                    foreach ($machine in Get-Content $list) {
                        $Provisioned = ProvisionBlob($machine, $domain)
                        if ($Provisioned) {
                            TextBox "Provisioning has been completed." "Provisioning Complete" "Ok" "Info"
                            $FTPSent = FTPSend($machine, $FTPServer, $FTPServerUN, $FTPServerPW)
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
            }
        } until ($ready -eq "Yes")
    }
}