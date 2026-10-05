param(
  [Parameter(Mandatory=$true)][int]$CliProcessId,
  [Parameter(Mandatory=$true)][string]$RulesPath
)
$ErrorActionPreference = 'Stop'
$taskRules = [System.IO.Path]::GetFullPath($RulesPath)
foreach ($taskProcess in Get-CimInstance Win32_Process -Filter "ParentProcessId = $CliProcessId AND Name = 'java.exe'") {
  if ($taskProcess.CommandLine.Contains('--project_id demo-bookself') -and
      $taskProcess.CommandLine.Contains('--host 127.0.0.1') -and
      $taskProcess.CommandLine.Contains($taskRules)) {
    Stop-Process -Id $taskProcess.ProcessId -Force
    Write-Output 'Processo Java do emulador demo deste teste encerrado.'
  }
}
