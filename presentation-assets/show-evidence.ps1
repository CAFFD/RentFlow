param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Title
)
$ErrorActionPreference = 'Stop'
Clear-Host
Write-Host 'RENTFLOW | EVIDENCIA REAL' -ForegroundColor Cyan
Write-Host $Title -ForegroundColor Yellow
Write-Host ''
Get-Content -LiteralPath $Source -Encoding utf8
Write-Host ''
Write-Host 'PASS | saida extraida da transcricao validada' -ForegroundColor Green
