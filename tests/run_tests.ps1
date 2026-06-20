# serez-cobol test runner
# For each examples/<name>.cob: translate with cobol.sz, run the generated .sz,
# and compare stdout against examples/<name>.expected (golden).
#   .\tests\run_tests.ps1            # run all
#   .\tests\run_tests.ps1 -generate  # (re)create the .expected golden files

param([switch]$generate = $false)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$examples = Join-Path $root "examples"

# Locate the sz interpreter (release build of the core).
$candidates = @(
    "C:\Program Files\Serez-Code\bin\sz.exe",
    "E:\01 Proyectos\Propio\Serez-code\target\release\sz.exe",
    "E:\01 Proyectos\Propio\Serez-code\target\debug\sz.exe"
)
$sz = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $sz) { Write-Host "sz.exe not found (build serez-code first)" -ForegroundColor Red; exit 1 }

$pass = 0; $fail = 0

function Run-Sz([string]$file, [string[]]$extra) {
    $outFile = [System.IO.Path]::GetTempFileName()
    $errFile = [System.IO.Path]::GetTempFileName()
    $argList = @("`"$file`"") + $extra
    Start-Process -FilePath $sz -ArgumentList $argList -NoNewWindow -Wait `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    $out = if (Test-Path $outFile) { Get-Content $outFile -Raw } else { "" }
    Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
    return ($out ?? "")
}

Get-ChildItem $examples -Filter "*.cob" | Sort-Object Name | ForEach-Object {
    $name = $_.BaseName
    $cob  = $_.FullName
    $szOut = Join-Path $examples "$name.sz"
    $expected = Join-Path $examples "$name.expected"

    # translate
    Run-Sz (Join-Path $root "cobol.sz") @("`"$cob`"") | Out-Null
    if (-not (Test-Path $szOut)) {
        Write-Host "[FAIL] $name — translation produced no .sz" -ForegroundColor Red
        $script:fail++; return
    }
    # run generated program
    $actual = (Run-Sz $szOut @()).Replace("`r`n", "`n").TrimEnd("`n")

    if ($generate) {
        Set-Content $expected $actual -NoNewline
        Write-Host "[GEN]  $name" -ForegroundColor Cyan
        return
    }
    if (-not (Test-Path $expected)) {
        Write-Host "[SKIP] $name (no .expected — run with -generate)" -ForegroundColor Yellow
        return
    }
    $want = (Get-Content $expected -Raw).Replace("`r`n", "`n").TrimEnd("`n")
    if ($actual -eq $want) {
        Write-Host "[PASS] $name" -ForegroundColor Green
        $script:pass++
    } else {
        Write-Host "[FAIL] $name" -ForegroundColor Red
        Write-Host "------ expected ------" -ForegroundColor Yellow; Write-Host $want
        Write-Host "------ actual --------" -ForegroundColor Yellow; Write-Host $actual
        $script:fail++
    }
}

Write-Host ""
Write-Host "TOTAL: $pass passed  $fail failed" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Green" })
exit $(if ($fail -gt 0) { 1 } else { 0 })
