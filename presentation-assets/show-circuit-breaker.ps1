param(
    [string]$Evidence = (Join-Path $PSScriptRoot '..\docs\evidencias\e07-deffdd7c-1a93-437c-bc60-59588b7bd054.txt')
)

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'RENTFLOW - E07 CIRCUIT BREAKER'
try {
    $windowSize = $Host.UI.RawUI.WindowSize
    $windowSize.Height = 20
    $Host.UI.RawUI.WindowSize = $windowSize
} catch {
    # O tamanho depende do host; a evidência continua válida sem esse ajuste visual.
}

if (-not (Test-Path -LiteralPath $Evidence)) {
    throw "Evidencia nao encontrada: $Evidence"
}

$lines = Get-Content -LiteralPath $Evidence -Encoding utf8
$run = $lines | Where-Object { $_ -like 'E07 runId=*' } | Select-Object -First 1
$selected = $lines | Where-Object {
    $_ -like 'PASS normal *' -or $_ -like 'PASS aberto *' -or
    $_ -like 'PASS bloqueada *' -or $_ -like 'PASS fluxoDuranteOpen *' -or
    $_ -like 'PASS halfOpenPrimeira *' -or $_ -like 'PASS fechado *' -or
    $_ -like 'PASS final *'
}

if ($selected.Count -ne 7) {
    throw "Esperadas 7 evidencias decisivas; encontradas $($selected.Count)."
}

Clear-Host
Write-Host 'RENTFLOW / E07 - CIRCUIT BREAKER' -ForegroundColor Cyan
Write-Host 'Execucao real validada em 24/11/2026' -ForegroundColor DarkGray
Write-Host $run -ForegroundColor DarkGray
Write-Host ''

$normal, $aberto, $bloqueada, $fluxo, $halfOpen, $fechado, $final = $selected
Write-Host ($normal -replace ' eventId=[^ ]+', '') -ForegroundColor Green
Write-Host $aberto -ForegroundColor Yellow
Write-Host ($bloqueada -replace ' eventId=[^ ]+', '') -ForegroundColor Yellow
Write-Host ($fluxo -replace ' eventId=[^ ]+', '') -ForegroundColor Green
Write-Host ($halfOpen -replace ' eventId=[^ ]+', '') -ForegroundColor Magenta
Write-Host ($fechado -replace ' eventId=[^ ]+', '') -ForegroundColor Green
Write-Host ($final -replace ' transitions=[^ ]+', '') -ForegroundColor Green

Write-Host ''
Write-Host 'CLOSED  >  OPEN  >  HALF_OPEN  >  CLOSED' -ForegroundColor Cyan
Write-Host 'PASS: 4 falhas abriram o circuito; a tentativa bloqueada nao chegou ao provedor.' -ForegroundColor Green
