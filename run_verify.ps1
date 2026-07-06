# Arrow Escape - Run all 5 verification chunks in parallel via flutter test
# Each chunk runs as a separate flutter test process.
# Logs: assets/chunk_1_log.txt ... assets/chunk_5_log.txt
# Progress: assets/verify_progress_chunk_N.json
#
# Usage:
#   .\run_verify.ps1            run all 5 chunks (skips already-passing levels)
#   .\run_verify.ps1 -Chunk 3   run only chunk 3
#   .\run_verify.ps1 -Reset     clear all progress and re-run everything
#
# When all 500 levels pass:
#   flutter test test/build_levels_bin_test.dart --no-pub

param(
  [int]$Chunk = 0,    # 0 = all chunks
  [switch]$Reset
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

# Ensure assets dir exists
New-Item -ItemType Directory -Force -Path "$root\assets" | Out-Null

# --Reset: clear chunk progress files and chunk logs
if ($Reset) {
  Write-Host "Resetting all progress..." -ForegroundColor Yellow
  1..5 | ForEach-Object {
    Remove-Item -Force "$root\assets\verify_progress_chunk_${_}.json" -ErrorAction SilentlyContinue
    Remove-Item -Force "$root\assets\chunk_${_}_log.txt" -ErrorAction SilentlyContinue
  }
  Write-Host "Progress cleared." -ForegroundColor Green
  Write-Host ""
}

# Print current summary before starting
function Show-Summary {
  $passCount = 0
  $failCount = 0
  $unrunCount = 500
  $failedLevels = @()

  1..5 | ForEach-Object {
    $pf = "$root\assets\verify_progress_chunk_${_}.json"
    if (Test-Path $pf) {
      try {
        $json = Get-Content $pf -Raw
        if ($json.Trim() -ne "") {
          $p = $json | ConvertFrom-Json
          if ($p) {
            foreach ($prop in $p.PSObject.Properties) {
              $lvlNum = [int]$prop.Name
              $status = $prop.Value.status
              $unrunCount--
              if ($status -eq 'pass') {
                $passCount++
              } else {
                $failCount++
                $failedLevels += $lvlNum
              }
            }
          }
        }
      } catch {
        # ignore read errors
      }
    }
  }

  Write-Host "  Progress: $passCount/500 pass | $failCount fail | $unrunCount not yet run" -ForegroundColor Cyan
  if ($failedLevels.Count -gt 0) {
    $failedLevels = $failedLevels | Sort-Object
    Write-Host "  Failed:   $($failedLevels -join ', ')" -ForegroundColor Red
  }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " Arrow Escape - Parallel Level Verification" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Show-Summary
Write-Host ""

# Determine chunks to run
$chunks = if ($Chunk -gt 0) { @($Chunk) } else { 1..5 }
Write-Host "Starting $($chunks.Count) chunk(s) in parallel via flutter test..." -ForegroundColor Green
Write-Host "Live logs: assets/chunk_N_log.txt"
Write-Host ""

$sw = [System.Diagnostics.Stopwatch]::StartNew()

# Start each chunk as a background job
$jobs = @()
foreach ($c in $chunks) {
  $job = Start-Job -Name "Chunk$c" -ScriptBlock {
    param($chunkNum, $dir)
    Set-Location $dir
    flutter test test/verify_chunk_${chunkNum}_test.dart --no-pub 2>&1
  } -ArgumentList $c, $root
  $jobs += $job
  Write-Host "  Started chunk $c (job $($job.Id))"
}

Write-Host ""
Write-Host "Waiting for all chunks to finish..." -ForegroundColor Yellow
Write-Host "(Tail a log with:  Get-Content assets\chunk_1_log.txt -Wait)"
Write-Host ""

# Poll and report completions
$pending = $jobs | ForEach-Object { $_.Id }
while ($pending.Count -gt 0) {
  Start-Sleep -Seconds 8
  $finished = @()
  foreach ($jobId in $pending) {
    $job = Get-Job -Id $jobId -ErrorAction SilentlyContinue
    if ($null -eq $job -or $job.State -in "Completed","Failed","Stopped") {
      $chunkNum = (Get-Job -Id $jobId -ErrorAction SilentlyContinue).Name -replace "Chunk",""
      $elapsed  = [int]$sw.Elapsed.TotalSeconds
      $color = "Green"
      if ($job.State -ne "Completed") { $color = "Red" }
      Write-Host "  Chunk $chunkNum finished [$($elapsed)s]  (state: $($job.State))" -ForegroundColor $color
      Remove-Job -Id $jobId -Force -ErrorAction SilentlyContinue
      $finished += $jobId
    }
  }
  $pending = $pending | Where-Object { $_ -notin $finished }
}

$sw.Stop()
Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "All done in $([int]$sw.Elapsed.TotalSeconds)s" -ForegroundColor Green
Show-Summary
Write-Host ""
Write-Host "Next step (when all 500 pass):" -ForegroundColor Yellow
Write-Host "  flutter test test/build_levels_bin_test.dart --no-pub" -ForegroundColor Cyan
Write-Host ""
