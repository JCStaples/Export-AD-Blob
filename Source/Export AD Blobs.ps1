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
    Version: 1.0
    Author: Jack Staples
#>

<#Frameworks#>
Add-Type -AssemblyName PresentationFramework #Allows use of System.Windows.Messagebox

<#Variables#>
$dir = "C:\Temp\ADJoin\" #dir folder location
$list = "$dir\DeviceList.txt" #DeviceList.txt file location
$domain = (Get-WmiObject Win32_ComputerSystem).Domain #Domain

#Dependencies Check
function CheckDepend() {
    #dir Directory Check
    if (!(Test-Path $dir)) {
        New-Item $dir -ItemType Directory
    }
}

<#Display Text Box#>
function TextBox($message, $title, $buttons, $icon) { #Shortened function for textboxes
    $buttonstate = [System.Windows.Messagebox]::Show($message, $title, $buttons, $icon) #Display message box
    Return $buttonstate
}

function FTPSend($dir, $machine) {
    #Config
    #Production
    $HostName = "27.33.253.184"
    $UserName = "ad.upload"
    #$Password = "b&eu%sx2!9^G2nC!t!HhDM6!"
    $Password = "01000000d08c9ddf0115d1118c7a00c04fc297eb01000000d30d43f63f145d4bb63cf7d2b0820c9d0000000002000000000010660000000100002000000080e81648c49c4331bf13dd2a6ab93c56d244d35aec0d000ecae15b679490967e000000000e800000000200002000000045242fc8a3b8890b858fb153cbba148acc347f3916e6397c1ca02a30e97175f240000000020b019327ef6fbfbfd2b1a5e032b73bc803eaf177037ddb4f62e3caa9a14b974122976681cbc4d4bd7f109c0987c3ed9f351c84e82e76add79b335bcd65b137400000005713363fe13b9c57a1ed8aea8a75d1b535a22a1d8229abf973386dcaeac8dc5b5945eb97714e92fdb5553059c34e9747f913bbfb8395582f0e7e2c1e524c6b77"
    $SecurePwd = $Password | ConvertFrom-SecureString
    #Files
    $LocalFile = "$dir$machine"
    $RemoteFile = "ftp://$hostname/$machine"
    #Create FTP Rquest Object
    $FTPRequest = [System.Net.FtpWebRequest]::Create("$RemoteFile")
    $FTPRequest = [System.Net.FtpWebRequest]$FTPRequest; $FTPRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
    $FTPRequest.Credentials = New-Object System.Net.NetworkCredential($Username, $SecurePwd)
    $FTPRequest.UseBinary = $true
    $FTPRequest.UsePassive = $true
    #Read the File for Upload
    $FileContent = Get-Content -en byte $LocalFile
    $FTPRequest.ContentLength = $FileContent.Length
    #Get Stream Request by bytes
    $Run = $FTPRequest.GetRequestStream()
    $Run.Write($FileContent, 0, $FileContent.Length)
    #Cleanup
    $Run.Close()
    $Run.Dispose()
}

#PROVISION BLOB FILE
function ProvisionBlob () {
    #Blob file provisioning function.
    foreach ($machine in Get-Content $list) {
        if (Test-Path $dir$machine) {
            #Check if device is already provisioned
            FTPSend $dir $machine
            Remove-Item $dir$machine
        }
        else {
            Djoin /provision /domain $domain /machine $machine /savefile $dir$machine /reuse #Generate blob file
            #Test File Start
            #New-Item $dir$machine
            #(Write-Host "$machine.$domain") *>> $dir$machine
            #Test File End
            FTPSend $dir $machine
            Remove-Item $dir$machine
        }
        
    }
}

#USE/CREATE DEVICELIST.TXT
& {
    #Check Dependencies
    CheckDepend
    if (Test-Path $list) {
        #Tests for DeviceList.txt file and provisions listed devices to domain if found
        ProvisionBlob #Provision function called
        Remove-Item $dir"DeviceList.txt"
        TextBox "Provisioning has been completed." "Provisioning Complete" "Ok" "Info"
    }
    else {
        #Tests for DeviceList.txt and creates file if not found. Then provisions listed devices to domain
        New-Item -Path $list -ItemType File #Create DeviceList.txt
        TextBox "Please enter device names line by line. Then save and close notepad to continue." "Instructions" "Ok" "Info" #$list instructions
        do {
            #Enter loop until condition on ln 116.
            #Open DeviceList.txt
            notepad $list; $nid = (Get-Process notepad).Id; Wait-Process -Id $nid;
            $ready = TextBox "Are you ready to continue?" "Continue..." "YesNo" "Info" #Yes will provision devices, no will open notepad for editing $list
            switch ($ready) {
                "Yes" {
                    ProvisionBlob #Provision function called
                    Remove-Item $dir"DeviceList.txt"
                    TextBox "Provisioning has been completed." "Provisioning Complete" "Ok" "Info"
                }
            }
        } until ($ready -eq "Yes") #Loops through above process until "Yes" is selected
    }
}