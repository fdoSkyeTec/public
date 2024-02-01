$rootFolder = "C:\Packages\Plugins\"
$avdAgentInstaller = $rootFolder+"WVD-Agent.msi"
$avdBootLoaderInstaller = $rootFolder+"WVD-BootLoader.msi"

##agents to download
$files = @(
    @{url = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv"; path = $avdAgentInstaller}
    @{url = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH"; path = $avdBootLoaderInstaller}
)


foreach ($file in $files ) {
  $i += 1
  $uriwithblob = $file.url
  $local = $file.path
  Start-Job {$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri $using:uriwithblob  -Method Get -OutFile $using:local} -Name "scriptjob$i"   
}
do {
$ii += 1
if (Get-Job -State Running) { $Stoploop = $true;Start-Sleep -Seconds 20 } else {$Stoploop = $false}
Write-Output "Count $ii, still running jobs.."  
}
While ($Stoploop -eq $true)
