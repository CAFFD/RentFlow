$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../scripts/comum.ps1"

$runId = [guid]::NewGuid().ToString()
$outputPath = Join-Path $PSScriptRoot '03-experiments/08-idempotencia-terminal.txt'
$lines = [System.Collections.Generic.List[string]]::new()

function Show-Line([string]$text, [ConsoleColor]$color = [ConsoleColor]::Gray) {
    $lines.Add($text)
    Write-Host $text -ForegroundColor $color
}

function Wait-Until([scriptblock]$condition, [string]$description) {
    $limit = [DateTime]::UtcNow.AddSeconds(35)
    do {
        if (& $condition) { return }
        Start-Sleep -Milliseconds 350
    } until ([DateTime]::UtcNow -gt $limit)
    throw "Timeout aguardando $description"
}

$composeConfig = Compose config --format json | Out-String | ConvertFrom-Json
$postgres = $composeConfig.services.postgres.environment
function Sql([string]$query) {
    $result = Compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U $postgres.POSTGRES_USER -d $postgres.POSTGRES_DB -At -F '|' -c $query
    ($result -join '').Trim()
}

$mainQueues = @((& "$PSScriptRoot/../scripts/filas.ps1") | Where-Object name -Like '*.queue')
if (@($mainQueues | Where-Object { $_.messages_ready -ne 0 -or $_.messages_unacknowledged -ne 0 }).Count) {
    throw 'As cinco filas principais precisam estar vazias antes da demonstracao.'
}

Show-Line '==============================================================================='
Show-Line ' RENTFLOW | DEMONSTRACAO REAL DE IDEMPOTENCIA' Cyan
Show-Line ' Um eventId, duas publicacoes, uma unica autorizacao' DarkCyan
Show-Line '==============================================================================='

$first = & "$PSScriptRoot/../scripts/disparar.ps1" -Tipo 'reserva.confirmada' -Execucao "demo-idempotencia-$runId"
if ($first.estado -ne 'PUBLICADO') { throw "Primeira publicacao falhou: $($first.estado)" }
$eventId = [guid]$first.eventId

Show-Line ''
Show-Line '[1] PRIMEIRA PUBLICACAO AMQP' Yellow
Show-Line "    eventId   = $eventId" White
Show-Line "    attemptId = $($first.attemptId)"
Show-Line "    estado    = $($first.estado)" Green

$sqlCount = "SELECT count(*) FROM retirada.efeitos WHERE event_id='$eventId';"
$sqlRecord = "SELECT reserva_id FROM retirada.efeitos WHERE event_id='$eventId';"
Wait-Until { (Sql $sqlCount) -eq '1' } 'primeira autorizacao no PostgreSQL'
$beforeCount = Sql $sqlCount
$reservationId = Sql $sqlRecord

Show-Line ''
Show-Line '[2] POSTGRESQL APOS O PRIMEIRO PROCESSAMENTO' Yellow
Show-Line "    SQL> $sqlCount" DarkGray
Show-Line "    autorizacoes = $beforeCount" Green
Show-Line "    reserva_id    = $reservationId"

$replay = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8080/events/$eventId/replay" -TimeoutSec 15
if ($replay.estado -ne 'PUBLICADO' -or [guid]$replay.eventId -ne $eventId) { throw 'Replay nao preservou o evento publicado.' }

Show-Line ''
Show-Line '[3] REPUBLICACAO DO MESMO ENVELOPE' Yellow
Show-Line "    eventId   = $($replay.eventId)  (MESMO ID)" White
Show-Line "    attemptId = $($replay.attemptId)  (NOVA TENTATIVA)"
Show-Line "    estado    = $($replay.estado)" Green

$runtime = Get-Content -LiteralPath (Join-Path $raiz '.runtime/retirada.json') -Raw | ConvertFrom-Json
Wait-Until {
    [bool](Select-String -LiteralPath $runtime.log -Pattern "eventId=$eventId .*outcome=ACK_DUPLICATA" -Quiet)
} 'ACK_DUPLICATA da retirada'
$duplicateLog = (Select-String -LiteralPath $runtime.log -Pattern "eventId=$eventId .*outcome=ACK_DUPLICATA" | Select-Object -Last 1).Line
$logStart = $duplicateLog.IndexOf("eventId=$eventId")
if ($logStart -ge 0) { $duplicateLog = $duplicateLog.Substring($logStart) }

Show-Line ''
Show-Line '[4] CONSUMIDOR RETIRADA' Yellow
Show-Line "    $duplicateLog" Magenta

Wait-Until { (Sql $sqlCount) -eq '1' } 'confirmacao final no PostgreSQL'
$afterCount = Sql $sqlCount
if ($beforeCount -ne '1' -or $afterCount -ne '1') { throw 'A autorizacao foi duplicada.' }

Show-Line ''
Show-Line '[5] POSTGRESQL APOS O REPLAY' Yellow
Show-Line "    SQL> $sqlCount" DarkGray
Show-Line "    autorizacoes = $afterCount" Green
Show-Line ''
Show-Line ' PASS | DUAS PUBLICACOES, ACK_DUPLICATA E UMA AUTORIZACAO' Green
Show-Line '==============================================================================='

[IO.File]::WriteAllLines($outputPath, $lines, [Text.UTF8Encoding]::new($false))
