. "$PSScriptRoot/comum.ps1"
& "$PSScriptRoot/topologia.ps1"
$cabecalho = Cabecalho-Local
$nomes = 'retirada.queue','comunicacao.queue','manutencao.queue','auditoria.queue','preparacao.queue'
function Contagens {
    $filas = Consultar-Api 'queues/rentflow'
    foreach ($nome in $nomes) {
        $q = $filas | Where-Object name -eq $nome
        if ($null -eq $q.messages_ready -or $null -eq $q.consumers -or $null -eq $q.messages_unacknowledged) { throw "Metricas indisponiveis: $nome" }
        if ($q.consumers -ne 0 -or $q.messages_unacknowledged -ne 0) { throw "Fila em uso: $nome" }
        [int]$q.messages_ready
    }
}
$matriz = [ordered]@{
    'reserva.confirmada' = 1,1,0,1,1
    'reserva.cancelada' = 0,1,0,1,0
    'inspecao.aprovada' = 0,0,1,1,0
    'inspecao.reprovada' = 0,1,1,1,0
    'inspecao.agendada' = 0,0,1,1,0
    'equipamento.cadastrado' = 0,0,0,1,0
}
$runId = [guid]::NewGuid().ToString()
"EXP-01A runId=$runId UTC=$([datetime]::UtcNow.ToString('o'))"
"ordem=$($nomes -join ',')"
$esperadoAntes = @(0,0,0,0,0)
foreach ($tipo in $matriz.Keys) {
    $antes = @(Contagens)
    if (($antes -join ',') -ne ($esperadoAntes -join ',')) { throw "FAIL $tipo baseline=$antes esperado=$esperadoAntes. Preserve as mensagens e aguarde a expiracao dos testes." }
    $previsto = $matriz[$tipo]
    $agora = [datetime]::UtcNow
    $id = [guid]::NewGuid().ToString()
    $dados = @{ equipamentoId = "EQ-$runId"; equipamento = 'Gerador ficticio' }
    if ($tipo -like 'reserva.*') { $dados.reservaId = "RES-$runId"; $dados.cliente = 'Cliente de laboratorio' }
    if ($tipo -eq 'reserva.confirmada') { $dados.retiradaInicio = $agora.AddDays(1).ToString('o'); $dados.retiradaFim = $agora.AddDays(1).AddHours(2).ToString('o') }
    if ($tipo -like 'inspecao.*') { $dados.inspecaoId = "INS-$id" }
    if ($tipo -eq 'inspecao.reprovada') { $dados.motivo = 'Falha ficticia'; $dados.destinatario = 'Oficina de laboratorio' }
    if ($tipo -eq 'inspecao.agendada') { $dados.agendadaPara = $agora.AddDays(1).ToString('o') }
    $evento = @{ eventId=$id; eventType=$tipo; occurredAt=$agora.ToString('o'); schemaVersion=1; data=$dados }
    $props = @{ content_type='application/json'; delivery_mode=2; expiration='3600000'; message_id=$id; headers=@{experimento='EXP-01A'; runId=$runId} }
    $corpo = @{ properties=$props; routing_key=$tipo; payload=($evento | ConvertTo-Json -Compress -Depth 5); payload_encoding='string' } | ConvertTo-Json -Compress -Depth 5
    "$tipo eventId=$id antes=$($antes -join ',') previsto=$($previsto -join ',')"
    $resposta = Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:15672/api/exchanges/rentflow/rentflow.events/publish' -Headers $cabecalho -ContentType 'application/json' -Body $corpo -TimeoutSec 8 -MaximumRedirection 0
    if (!$resposta.routed) { throw "FAIL $tipo routed=false" }
    $limite = [datetime]::UtcNow.AddSeconds(35)
    do {
        Start-Sleep -Seconds 1
        $depois = @(Contagens)
        $delta = @(for ($i=0; $i -lt 5; $i++) { $depois[$i] - $antes[$i] })
        $confere = ($delta -join ',') -eq ($previsto -join ',')
    } until ($confere -or [datetime]::UtcNow -ge $limite)
    $resultado = if ($confere) { 'PASS' } else { 'FAIL' }
    "$resultado $tipo routed=true depois=$($depois -join ',') delta=$($delta -join ',')"
    if (!$confere) { throw "EXP-01A divergiu em $tipo" }
    $esperadoAntes = $depois
}
"PASS final=$($depois -join ',') total=$(($depois | Measure-Object -Sum).Sum)"
