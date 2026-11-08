<#
Resolves uninstall commands for machine-wide apps matching -Patterns, writes ONE elevated
script, launches it (one UAC prompt), waits for it and prints the log.
  -DryRun          show the resolved commands only; run nothing
  -CleanSystemTemp also clear C:\Windows\Temp and the Windows Update download cache
  -RemoveHklmRun   names of HKLM Run startup values to remove (a backup goes to WorkDir)
#>
param(
  [Parameter(Mandatory)][string[]]$Patterns,
  [Parameter(Mandatory)][string]$WorkDir,
  [string[]]$RemoveHklmRun = @(),
  [switch]$CleanSystemTemp,
  [switch]$DryRun,
  [int]$TimeoutSec = 1800
)
# "powershell -File" passes 'a','b' as one string, so split on commas as well
$Patterns = @($Patterns | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$RemoveHklmRun = @($RemoveHklmRun | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
New-Item -ItemType Directory -Force $WorkDir | Out-Null
$keys = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
$apps = Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $n = $_.DisplayName; $n -and ($Patterns | Where-Object { $n -match $_ }) }

$cmds = foreach ($a in $apps) {
  $u = if ($a.QuietUninstallString) { $a.QuietUninstallString } else { $a.UninstallString }
  $guid = if ($a.PSChildName -match '^\{[0-9A-Fa-f-]+\}$') { $a.PSChildName } elseif ($u -match '(\{[0-9A-Fa-f-]{36}\})') { $Matches[1] }
  if ($u -match 'OfficeClickToRun\.exe') {
    $exe = ($u -split '"')[1]; $args_ = ($u -split '"', 3)[2].Trim() + ' DisplayLevel=False'
    [pscustomobject]@{ Name=$a.DisplayName; Kind='office'; Exe=$exe; Args=$args_ }
  } elseif ($guid -and ($a.WindowsInstaller -eq 1 -or $u -match 'msiexec')) {
    [pscustomobject]@{ Name=$a.DisplayName; Kind='msi'; Exe='msiexec.exe'; Args="/x $guid /qn /norestart" }
  } elseif ($u) {
    if ($u -match '^"([^"]+)"\s*(.*)$') { $exe=$Matches[1]; $rest=$Matches[2] } elseif ($u -match '^(.+?\.exe)\s*(.*)$') { $exe=$Matches[1]; $rest=$Matches[2] } else { $exe=$u; $rest='' }
    if ($exe -match 'unins\d+\.exe$' -and $rest -notmatch 'SILENT') { $rest = "$rest /VERYSILENT /NORESTART".Trim() }
    [pscustomobject]@{ Name=$a.DisplayName; Kind='exe'; Exe=$exe; Args=$rest }
  } else {
    [pscustomobject]@{ Name=$a.DisplayName; Kind='none'; Exe=''; Args='' }
  }
}
$cmds = $cmds | Sort-Object Name -Unique
"Resolved:"; $cmds | Format-Table Name, Kind, Exe, Args -AutoSize | Out-String -Width 300
if ($DryRun) { return }

$log = Join-Path $WorkDir 'uninstall-log.txt'
$script = Join-Path $WorkDir 'uninstall-elevated.ps1'
$json = Join-Path $WorkDir 'uninstall-plan.json'
@{ cmds = @($cmds); run = $RemoveHklmRun; temp = [bool]$CleanSystemTemp } | ConvertTo-Json -Depth 4 | Out-File $json -Encoding utf8

@'
param($Plan, $Log)
function L($m) { "$(Get-Date -f HH:mm:ss) $m" | Out-File $Log -Append -Encoding utf8 }
$p = Get-Content $Plan -Raw | ConvertFrom-Json
L 'START'
foreach ($c in $p.cmds) {
  if ($c.Kind -eq 'none') { L "SKIP (no uninstall command) $($c.Name)"; continue }
  if (-not (Test-Path $c.Exe) -and $c.Kind -ne 'msi') { L "SKIP (missing $($c.Exe)) $($c.Name)"; continue }
  for ($i = 1; $i -le 4; $i++) {
    try { $r = Start-Process $c.Exe $c.Args -Wait -PassThru -ErrorAction Stop; $code = $r.ExitCode } catch { $code = "ERR $($_.Exception.Message)" }
    if ($code -ne 1618) { break }
    L "1618 busy, retry $i for $($c.Name)"; Start-Sleep 20
  }
  L "$($c.Kind) '$($c.Name)' exit $code"
}
$runKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
foreach ($n in $p.run) {
  $v = (Get-ItemProperty $runKey -Name $n -ErrorAction SilentlyContinue).$n
  if ($v) { "$n = $v" | Out-File (Join-Path (Split-Path $Log) 'startup-backup-hklm.txt') -Append -Encoding utf8; Remove-ItemProperty $runKey -Name $n; L "removed HKLM Run '$n'" }
}
if ($p.temp) {
  Remove-Item "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
  L 'system temp cleaned'
}
L 'DONE'
'@ | Out-File $script -Encoding utf8

$startLines = if (Test-Path $log) { (Get-Content $log).Count } else { 0 }
Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$script`" -Plan `"$json`" -Log `"$log`"" -Verb RunAs
"Launched elevated script - approve the UAC prompt and click through any uninstaller windows."
$t = 0
while ($t -lt $TimeoutSec) {
  if (Test-Path $log) { $new = Get-Content $log | Select-Object -Skip $startLines; if ($new -match 'DONE$') { break } }
  Start-Sleep 10; $t += 10
}
if (Test-Path $log) { Get-Content $log | Select-Object -Skip $startLines } else { "No log - the UAC prompt was probably declined." }
