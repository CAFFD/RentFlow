param([ValidateSet('completo','matriz','concorrencia','interrupcao','duplicidade','conflito','falha')] [string]$Cenario='completo')
. "$PSScriptRoot/comum.ps1"
$run=[guid]::NewGuid().ToString()
$arquivoRun=Join-Path $raiz "docs/evidencias/exp-nucleo-$run.txt"
function Registrar([string]$texto) {
    Write-Host $texto
    [IO.File]::AppendAllText($arquivoRun,$texto+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
}
trap {
    if ($arquivoRun) { Registrar "FAIL $($_.Exception.Message)" }
    throw $_
}
$ordem='retirada','comunicacao','manutencao','auditoria','preparacao'
$cabecalho=Cabecalho-Local
$cfg=Compose config --format json | Out-String | ConvertFrom-Json
$pg=$cfg.services.postgres.environment
function Sql($consulta) {
    $out=Compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U $pg.POSTGRES_USER -d $pg.POSTGRES_DB -Atc $consulta
    ($out -join '').Trim()
}
function Aguardar([scriptblock]$condicao,[string]$descricao) {
    $limite=[datetime]::UtcNow.AddSeconds(50)
    do {
        if (& $condicao) { return }
        Start-Sleep -Milliseconds 400
    } until ([datetime]::UtcNow -gt $limite)
    throw "Timeout: $descricao"
}
function Publicar($tipo,[switch]$gancho) {
    $res=& "$PSScriptRoot/disparar.ps1" -Tipo $tipo -Execucao $run -FalhaAposCommit:$gancho
    if ($res.estado -ne 'PUBLICADO') { throw "Tentativa sem confirm $($res.attemptId)" }
    Registrar "PUBLICADO tipo=$tipo eventId=$($res.eventId) attemptId=$($res.attemptId)"
    [guid]$res.eventId
}
function Efeito([int]$porta,[guid]$id) {
    $registros=Invoke-RestMethod "http://127.0.0.1:$porta/effects?eventId=$id" -TimeoutSec 5
    foreach($registro in $registros){$registro}
}
function Contar([guid]$id) { foreach ($porta in 8081..8085) { @(Efeito $porta $id).Count } }
function Fila($nome) { Consultar-Api "queues/rentflow/$nome.queue" }
function LogContem($app,$id,$texto) {
    $arquivo=(Get-Content "$raiz/.runtime/$app.json" -Raw | ConvertFrom-Json).log
    [bool](Select-String -LiteralPath $arquivo -Pattern "eventId=$id .*?$texto" -Quiet)
}
function RegistrarLog($app,[guid]$id) {
    $log=(Get-Content -Raw "$raiz/.runtime/$app.json" | ConvertFrom-Json).log
    foreach ($linha in Select-String -LiteralPath $log -SimpleMatch "eventId=$id ") {
        $inicio=$linha.Line.IndexOf("eventId=$id ")
        Registrar ("LOG " + $linha.Line.Substring($inicio))
    }
}
function Matriz {
    $invalido=0
    try {
        Invoke-RestMethod -Method Post 'http://127.0.0.1:8080/events/reserva.confirmada' -Body '{}' -ContentType application/json -TimeoutSec 10 | Out-Null
    } catch {
        if ($_.Exception.Response) { $invalido=[int]$_.Exception.Response.StatusCode } else { throw }
    }
    if ($invalido -ne 400) { throw "Evento invalido recebeu HTTP $invalido" }
    Registrar 'PASS JSON de reserva sem campos obrigatorios recebeu HTTP 400'
    $casos=[ordered]@{'reserva.confirmada'='1,1,0,1,1';'reserva.cancelada'='0,1,0,1,0';'inspecao.aprovada'='0,0,1,1,0';'inspecao.reprovada'='0,1,1,1,0';'inspecao.agendada'='0,0,1,1,0';'equipamento.cadastrado'='0,0,0,1,0'}
    foreach($tipo in $casos.Keys) {
        $previsto=$casos[$tipo]
        Registrar "PREVISAO $tipo $previsto"
        $id=Publicar $tipo
        Aguardar { ((Contar $id) -join ',') -eq $previsto } "efeitos $id"
        $fato=Invoke-RestMethod "http://127.0.0.1:8080/events/$id" -TimeoutSec 5
        $auditoria=Efeito 8084 $id
        if ($auditoria.original -cne $fato.original -or $fato.tentativas.Count -ne 1) { throw 'Envelope/confirm divergente' }
        $data=[uri]::EscapeDataString(([datetimeoffset]::Parse($fato.envelope.occurredAt).AddSeconds(-1)).ToString('o'))
        $fim=[uri]::EscapeDataString(([datetimeoffset]::Parse($fato.envelope.occurredAt).AddSeconds(1)).ToString('o'))
        $busca=Invoke-RestMethod "http://127.0.0.1:8084/effects?eventId=$id&eventType=$tipo&inicio=$data&fim=$fim" -TimeoutSec 5
        if ($busca.Count -ne 1) { throw 'Filtro de auditoria divergente' }
        if($tipo -eq 'inspecao.agendada' -and $null -ne (Efeito 8083 $id).resultado){ throw 'Resultado inventado' }
        $dados=$fato.envelope.data
        if($tipo -eq 'reserva.confirmada') {
            $r=Efeito 8081 $id
            $p=Efeito 8085 $id
            $inicio=[datetimeoffset]::Parse($dados.retiradaInicio)
            if($r.reserva_id -ne $dados.reservaId -or $r.cliente -ne $dados.cliente -or $r.equipamento -ne $dados.equipamento -or [datetimeoffset]::Parse($r.inicio) -ne $inicio -or [datetimeoffset]::Parse($r.fim) -ne [datetimeoffset]::Parse($dados.retiradaFim)) {throw 'Autorizacao divergente'}
            if($p.reserva_id -ne $dados.reservaId -or [datetimeoffset]::Parse($p.planejado) -ne $inicio.AddMinutes(-30)) {throw 'Prazo de preparacao divergente'}
        }
        if ($tipo -in 'reserva.confirmada','reserva.cancelada','inspecao.reprovada') {
            $aviso=Efeito 8082 $id
            if ($aviso.estado -ne 'PENDING' -or !$aviso.destinatario -or !$aviso.conteudo) { throw 'Aviso incompleto' }
        }
        if ($tipo -like 'inspecao.*') {
            $inspecao=Efeito 8083 $id
            if ($inspecao.dados.inspecaoId -ne $dados.inspecaoId) {throw 'Fato de inspecao divergente'}
            if ($tipo -eq 'inspecao.aprovada' -and $inspecao.resultado -ne 'APROVADA') {throw 'Resultado divergente'}
            if ($tipo -eq 'inspecao.reprovada' -and ($inspecao.resultado -ne 'REPROVADA' -or $inspecao.motivo -ne $dados.motivo)) {throw 'Reprovacao divergente'}
        }
        Registrar "PASS matriz $tipo observado=$((Contar $id) -join ',') auditoria=original confirm=$($fato.tentativas[0].motivo)"
    }
}
function TipoNovo {
    $id=Publicar 'inspecao.reaberta'
    Aguardar { ((Contar $id) -join ',') -eq '0,0,1,1,0' } 'inspecao nova'
    $manutencao=Efeito 8083 $id
    if($null -ne $manutencao.resultado -or $manutencao.dados.runId -ne $run) { throw 'Fato generico alterado' }
    Registrar "PASS extensibilidade eventId=$id tipo=inspecao.reaberta observado=0,0,1,1,0 resultado=NULL"
}
function Concorrencia {
    Aguardar { (Fila 'preparacao').consumers -eq 2 } 'dois workers'
    $ids=@(1..10 | ForEach-Object { Publicar 'reserva.confirmada' })
    if (@($ids | Sort-Object -Unique).Count -ne 10) { throw 'IDs repetidos' }
    $tarefas=@(foreach ($id in $ids) {
        Aguardar { ((Contar $id) -join ',') -eq '1,1,0,1,1' } "concorrencia $id"
        Efeito 8085 $id
    })
    $grupos=@($tarefas | Group-Object worker_id)
    if (($grupos.Name | Sort-Object) -join ',' -ne 'Worker-A,Worker-B') { throw 'Workers nao dividiram as tarefas' }
    foreach($grupo in $grupos) { Registrar "$($grupo.Name) tarefas=$($grupo.Count) ids=$($grupo.Group.event_id -join ',')" }
    Registrar 'PASS concorrencia ids=10 retirada=10 comunicacao=10 auditoria=10 preparacao=10'
}
function Interrupcao {
    Aguardar {
        $fila=Fila 'comunicacao'
        $fila.consumers -eq 1 -and $fila.messages_ready -eq 0 -and $fila.messages_unacknowledged -eq 0
    } 'linha de base antes da interrupcao'
    $antes=Fila 'comunicacao'
    Registrar "ANTES consumers=$($antes.consumers) ready=$($antes.messages_ready)"
    if ($antes.consumers -ne 1 -or $antes.messages_ready -ne 0) { throw 'Comunicacao fora da linha de base' }
    & "$PSScriptRoot/apps.ps1" parar comunicacao
    try {
        Aguardar { (Fila 'comunicacao').consumers -eq 0 } 'comunicacao offline'
        $id=Publicar 'reserva.confirmada'
        Aguardar { (Fila 'comunicacao').messages_ready -eq 1 -and @(Efeito 8081 $id).Count -eq 1 -and @(Efeito 8084 $id).Count -eq 1 -and @(Efeito 8085 $id).Count -eq 1 } 'outros destinos e Ready'
        $q=Fila 'comunicacao'
        $avisos=Sql "SELECT count(*) FROM comunicacao.efeitos WHERE event_id='$id'"
        if($avisos -ne '0'){throw 'Aviso antecipado'}
        Registrar "DURANTE eventId=$id consumers=$($q.consumers) ready=$($q.messages_ready) avisosSQL=$avisos retirada=1 auditoria=1 preparacao=1"
    } finally { & "$PSScriptRoot/apps.ps1" iniciar comunicacao }
    Aguardar { $q=Fila 'comunicacao'; $q.messages_ready -eq 0 -and $q.messages_unacknowledged -eq 0 -and $q.consumers -eq 1 -and @(Efeito 8082 $id).Count -eq 1 } 'retomada'
    Registrar "PASS DEPOIS eventId=$id consumers=1 ready=0 unacked=0 avisos=1"
}
function Duplicidade {
    $id=Publicar 'reserva.confirmada'
    Aguardar { ((Contar $id) -join ',') -eq '1,1,0,1,1' } 'efeitos antes do replay'
    $antes=Invoke-RestMethod "http://127.0.0.1:8080/events/$id" -TimeoutSec 5
    $replay=Invoke-RestMethod -Method Post "http://127.0.0.1:8080/events/$id/replay" -TimeoutSec 15
    $depois=Invoke-RestMethod "http://127.0.0.1:8080/events/$id" -TimeoutSec 5
    if ($replay.estado -ne 'PUBLICADO' -or $antes.original -cne $depois.original -or $depois.tentativas.Count -ne 2 -or $antes.tentativas[0].id -eq $replay.attemptId){throw 'Replay divergente'}
    foreach($app in 'retirada','comunicacao','auditoria'){ Aguardar { LogContem $app $id 'outcome=ACK_DUPLICATA' } "ACK duplicado $app" }
    Aguardar { (LogContem 'Worker-A' $id 'outcome=ACK_DUPLICATA') -or (LogContem 'Worker-B' $id 'outcome=ACK_DUPLICATA') } 'ACK duplicado preparacao'
    $sqlContagens=@(foreach ($schema in $ordem) { Sql "SELECT count(*) FROM $schema.efeitos WHERE event_id='$id'" })
    $porReserva=Sql "SELECT count(*) FROM retirada.efeitos WHERE reserva_id=(SELECT reserva_id FROM retirada.efeitos WHERE event_id='$id')"
    if (($sqlContagens -join ',') -ne '1,1,0,1,1' -or $porReserva -ne '1' -or ((Contar $id) -join ',') -ne '1,1,0,1,1'){throw 'Efeito duplicado'}
    foreach($instancia in 'retirada','comunicacao','auditoria','Worker-A','Worker-B'){ RegistrarLog $instancia $id }
    Registrar "PASS duplicidade eventId=$id tentativas=$($depois.tentativas.id -join ',') SQL=$($sqlContagens -join ',') autorizacoesPorReserva=$porReserva ACK_DUPLICATA=4 original=identico"
}
function Conflito {
    $primeiro=Publicar 'reserva.confirmada'
    Aguardar { ((Contar $primeiro) -join ',') -eq '1,1,0,1,1' } 'reserva original'
    $original=Invoke-RestMethod "http://127.0.0.1:8080/events/$primeiro" -TimeoutSec 5
    $filaAntes=Consultar-Api 'queues/rentflow/rentflow.estacionamento'
    $resposta=Invoke-RestMethod -Method Post -ContentType application/json -Uri 'http://127.0.0.1:8080/events/reserva.confirmada' -Body ($original.envelope.data | ConvertTo-Json -Compress) -TimeoutSec 15
    $segundo=[guid]$resposta.eventId
    if($resposta.estado -ne 'PUBLICADO' -or $segundo -eq $primeiro){throw 'Esperado novo fato confirmado'}
    Aguardar {
        $parking=Consultar-Api 'queues/rentflow/rentflow.estacionamento'
        $parking.messages_ready -eq ($filaAntes.messages_ready + 1) -and ((Contar $segundo) -join ',') -eq '0,1,0,1,1'
    } 'estacionamento da entrega em conflito'
    $marcas=Sql "SELECT count(*) FROM retirada.processed_events WHERE event_id='$segundo'"
    if($marcas -ne '0' -or @(Efeito 8081 $primeiro).Count -ne 1){throw 'Rollback incorreto'}
    RegistrarLog 'retirada' $segundo
    Registrar "PASS conflito antesCommit original=$primeiro novo=$segundo retiradaNova=0 marcaNovaSQL=$marcas retiradaOriginal=1 estacionamentoDelta=1"
}
function Falha {
    & "$PSScriptRoot/apps.ps1" parar retirada
    try {
        & "$PSScriptRoot/apps.ps1" iniciar retirada -TesteFalha
        $id=Publicar 'reserva.confirmada' -gancho
        Aguardar { (LogContem 'retirada' $id 'FALHA_SIMULADA_APOS_COMMIT') -and (LogContem 'retirada' $id 'redelivered=true') -and (LogContem 'retirada' $id 'ACK_DUPLICATA') } 'reentrega'
        if (@(Efeito 8081 $id).Count -ne 1) {throw 'Falha no efeito unico'}
        RegistrarLog 'retirada' $id
        Registrar "PASS falha eventId=$id commit=1 canalAbortadoAntesDoAck=1 redelivered=true ACK_DUPLICATA autorizacoes=1"
    } finally { & "$PSScriptRoot/apps.ps1" parar retirada; & "$PSScriptRoot/apps.ps1" iniciar retirada }
}
Registrar "RUN $run UTC=$([datetime]::UtcNow.ToString('o')) ordem=$($ordem -join ',')"
$principais=@((Consultar-Api 'queues/rentflow') | Where-Object name -like '*.queue')
if ($principais.Count -ne 5 -or @($principais | Where-Object { $null -eq $_.messages_ready -or $_.messages_ready -ne 0 -or $_.messages_unacknowledged -ne 0 }).Count) { throw 'Filas principais devem estar vazias, sem unacked' }
Aguardar {
    $q=Consultar-Api 'queues/rentflow'
    @($q | Where-Object { $_.name -like '*.queue' -and $_.consumers -eq 1 }).Count -eq 4 -and ($q | Where-Object name -eq 'preparacao.queue').consumers -eq 2
} 'seis consumidores nas cinco filas'
if ($Cenario -in 'completo','matriz') { Matriz; TipoNovo }
if ($Cenario -in 'completo','concorrencia') { Concorrencia }
if ($Cenario -in 'completo','interrupcao') { Interrupcao }
if ($Cenario -in 'completo','duplicidade') { Duplicidade }
if ($Cenario -in 'completo','conflito') { Conflito }
if ($Cenario -in 'completo','falha') { Falha }
