# Read-only survey of a Windows PC for debloating. Changes nothing.
$ErrorActionPreference = 'SilentlyContinue'
function Size($p) { (Get-ChildItem -LiteralPath $p -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum }
function GB($b) { [math]::Round($b / 1GB, 2) }

"=== SYSTEM ==="
$os = Get-CimInstance Win32_OperatingSystem
"{0} {1}" -f $os.Caption, $os.Version
"CPU: " + (Get-CimInstance Win32_Processor).Name
"RAM GB total/free: {0} / {1}" -f [math]::Round($os.TotalVisibleMemorySize/1MB,1), [math]::Round($os.FreePhysicalMemory/1MB,1)
"Admin: " + ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Get-PSDrive -PSProvider FileSystem | Where-Object Used | ForEach-Object { "Drive {0}: used {1} GB, free {2} GB" -f $_.Name, (GB $_.Used), (GB $_.Free) }

"`n=== USER FOLDERS (GB) ==="
foreach ($f in 'Desktop','Documents','Downloads','Pictures','Videos','Music','OneDrive') {
  $p = Join-Path $env:USERPROFILE $f
  if (Test-Path $p) { "{0,-12} {1,8}" -f $f, (GB (Size $p)) }
}
foreach ($f in 'Desktop','Documents','Downloads') {
  $p = Join-Path $env:USERPROFILE $f
  if (-not (Test-Path $p)) { continue }
  "`n-- Biggest in $f --"
  Get-ChildItem $p -Force | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
    [pscustomobject]@{ Name = $_.Name; GB = GB $(if ($_.PSIsContainer) { Size $_.FullName } else { $_.Length }) }
  } | Sort-Object GB -Descending | Select-Object -First 15 | Format-Table -AutoSize | Out-String -Width 200
}

"=== JUNK (GB) ==="
foreach ($p in $env:TEMP, "$env:WINDIR\Temp", "$env:WINDIR\SoftwareDistribution\Download") { "{0,-50} {1}" -f $p, (GB (Size $p)) }
"Recycle bin items: " + (New-Object -ComObject Shell.Application).NameSpace(10).Items().Count

"`n=== STARTUP ==="
Get-CimInstance Win32_StartupCommand | Select-Object Name, Location, Command | Format-Table -AutoSize | Out-String -Width 250

"=== WIN32 APPS ==="
$keys = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
Get-ItemProperty $keys | Where-Object { $_.DisplayName -and -not $_.SystemComponent } |
  Select-Object DisplayName, Publisher, @{n='MB';e={[math]::Round($_.EstimatedSize/1KB)}}, @{n='Scope';e={ if ($_.PSPath -match 'HKEY_CURRENT_USER') {'user'} else {'machine'} }} |
  Sort-Object DisplayName -Unique | Format-Table -AutoSize | Out-String -Width 250

"=== STORE APPS (non-framework) ==="
Get-AppxPackage | Where-Object { -not $_.IsFramework -and $_.SignatureKind -eq 'Store' } | Select-Object -ExpandProperty Name | Sort-Object

"`n=== TOP MEMORY PROCESSES ==="
Get-Process | Group-Object Name | ForEach-Object { [pscustomobject]@{ Name = $_.Name; MB = [math]::Round(($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB) } } |
  Sort-Object MB -Descending | Select-Object -First 15 | Format-Table -AutoSize | Out-String
