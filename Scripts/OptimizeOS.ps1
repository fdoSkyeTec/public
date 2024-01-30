#*************************************************************************************
#* Author       : Rohan Islam                                                        *
#* Version      : v1.0                                                               *
#* Description  : OS optimization for VDI                                            *
#************************************************************************************* 

Write-Host "###### Starting OS optimization script ######"

#region: Variables
    $localPath = 'c:\temp\avd'
    $osOptURL = 'https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/archive/refs/heads/main.zip'
    $osOptFile = 'OptimizeOS-main.zip'
    $outputPath = $localPath + '\' + $osOptFile
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

#region: OS Optimizations for AVD
    Write-Host "Downloading OS Optimization Script"       
    Invoke-WebRequest -Uri $osOptURL -OutFile $outputPath
    Expand-Archive -LiteralPath $outputPath -DestinationPath $localPath -Force -Verbose

    Write-Host "Starting OS Optimizations script"       
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force -Verbose
    Set-Location -Path ($localPath + '\Virtual-Desktop-Optimization-Tool-main')
    .\Windows_VDOT.ps1 -WindowsVersion 2004 -Optimizations All -AcceptEula -Verbose
#endregion

Write-Host "###### OS optimization script is complete ######"