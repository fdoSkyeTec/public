#*************************************************************************************
#* Author       : Rohan Islam                                                        *
#* Version      : v1.0                                                               *
#* Description  : MS Teams installation for VDI                                      *
#************************************************************************************* 

Write-Host "###### Starting MS Teams installation script ######"
 
 #region: Variables
    $localPath = 'c:\temp\avd'
    $teamsURL = 'https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true'
    $teamsInstaller = 'teams.msi'
    $visCplusURL = 'https://aka.ms/vs/16/release/vc_redist.x64.exe'
    $visCplusInstaller = 'vc_redist.x64.exe'
    $webSocketsURL = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE4AQBt'
    $webSocketsInstaller = 'webSocketSvc.msi'
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

#region: Install MS Teams
    Write-Host "Configuring required registry key"       
    New-Item -Path HKLM:\SOFTWARE\Microsoft -Name "Teams" 
    New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Teams -Name "IsWVDEnvironment" -Type "Dword" -Value "1"

    Write-Host "Installing latest Microsoft Visual C++ Redistributable"       
    Invoke-WebRequest -Uri $visCplusURL -OutFile "$localPath\$visCplusInstaller"
    Start-Process -FilePath "$localPath\$visCplusInstaller" -Args "/install /quiet /norestart /log vcdist.log" -Wait

    Write-Host "Installing Teams WebSocket Service"       
    Invoke-WebRequest -Uri $webSocketsURL -OutFile "$LocalPath\$webSocketsInstaller"
    Start-Process -FilePath msiexec.exe -Args "/I $LocalPath\$webSocketsInstaller /quiet /norestart /log webSocket.log" -Wait

    Write-Host "Installing Teams"       
    Invoke-WebRequest -Uri $teamsURL -OutFile "$LocalPath\$teamsInstaller"
    Start-Process -FilePath msiexec.exe -Args "/I $LocalPath\$teamsInstaller /quiet /norestart /log teams.log ALLUSER=1 ALLUSERS=1" -Wait
#endregion

Write-Host "###### MS Teams installation script is complete ######"
