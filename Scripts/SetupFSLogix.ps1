#*************************************************************************************
#* Author       : Rohan Islam                                                        *
#* Version      : v1.0                                                               *
#* Description  : FSLogix installation for VDI                                       *
#************************************************************************************* 

Write-Host "###### Starting FSLogix installation script ######"

#region: Variables
    $localPath = 'c:\temp\avd'
    $fslogixURI = 'https://aka.ms/fslogix_download'
    $fslogixInstaller = 'FSLogixAppsSetup.zip'
#endregion

#region: Create staging directory
    if((Test-Path c:\temp) -eq $false) {
        Write-Host "Creating C:\temp directory"       
        New-Item -Path c:\temp -ItemType Directory
    }
    else {
        Write-Host "C:\temp directory already exists"

    }
    if((Test-Path $localPath) -eq $false) {
        Write-Host "Creating $localPath directory"    
        New-Item -Path $LocalPath -ItemType Directory
    }
    else {
        Write-Host "$localPath directory already exists"

    }
#endregion

#region: Download and install FSLogix
    Write-Host "Downloading FSLogix"
    Invoke-WebRequest -Uri $fslogixURI -OutFile "$LocalPath\$fslogixInstaller"

    Write-Host "Unzipping FSLogix"
    Expand-Archive `
        -LiteralPath "$LocalPath\$fslogixInstaller" `
        -DestinationPath "$LocalPath\FSLogix" `
        -Force `
        -Verbose
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Write-Host "Installing FSLogix"
    Start-Process `
        -FilePath "$LocalPath\FSLogix\x64\Release\FSLogixAppsSetup.exe" `
        -ArgumentList "/install /quiet /norestart" `
        -Wait `
        -Passthru
#endregion

#region: FSLogix user profile setting
    Write-Host "Configuring FSLogix Profile Settings"
    Push-Location 
    Set-Location HKLM:\SOFTWARE\
    New-Item `
        -Path HKLM:\SOFTWARE\FSLogix `
        -Name Profiles `
        -Value "" `
        -Force
    New-Item `
        -Path HKLM:\Software\FSLogix\Profiles\ `
        -Name Apps `
        -Force
    Set-ItemProperty `
        -Path HKLM:\Software\FSLogix\Profiles `
        -Name "Enabled" `
        -Type "Dword" `
        -Value "1"
    New-ItemProperty `
        -Path HKLM:\Software\FSLogix\Profiles `
        -Name "CCDLocations" `
        -Value "type=smb,connectionString=$ProfilePath" `
        -PropertyType MultiString `
        -Force
    Set-ItemProperty `
        -Path HKLM:\Software\FSLogix\Profiles `
        -Name "SizeInMBs" `
        -Type "Dword" `
        -Value "30000"
    Set-ItemProperty `
        -Path HKLM:\Software\FSLogix\Profiles `
        -Name "IsDynamic" `
        -Type "Dword" `
        -Value "1"
    Set-ItemProperty `
        -Path HKLM:\Software\FSLogix\Profiles `
        -Name "VolumeType" `
        -Type String `
        -Value "vhdx"
    Set-ItemProperty `
        -Path HKLM:\Software\FSLogix\Profiles `
        -Name "FlipFlopProfileDirectoryName" `
        -Type "Dword" `
        -Value "1" 
    Set-ItemProperty `
        -Path HKLM:\Software\FSLogix\Profiles `
        -Name "SIDDirNamePattern" `
        -Type String `
        -Value "%username%%sid%"
    Set-ItemProperty `
        -Path HKLM:\Software\FSLogix\Profiles `
        -Name "SIDDirNameMatch" `
        -Type String `
        -Value "%username%%sid%"
    Set-ItemProperty `
        -Path HKLM:\Software\FSLogix\Profiles `
        -Name DeleteLocalProfileWhenVHDShouldApply `
        -Type DWord `
        -Value 1
    Pop-Location
#endregion

Write-Host "###### FSLogix installation script is complete ######"