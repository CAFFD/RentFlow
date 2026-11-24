$ErrorActionPreference='Stop'
. "$PSScriptRoot/comum.ps1"
$run=[guid]::NewGuid().ToString()
$evidencia=Join-Path $raiz "docs/evidencias/e07-$run.txt"
$cabecalho=Cabecalho-Local

function Registrar([string]$texto) {
    Write-Host $texto
    [IO.File]::AppendAllText($evidencia,$texto+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
}
function Aguardar([scriptblock]$condicao,[string]$descricao,[int]$segundos=40) {
    $limite=[datetime]::UtcNow.AddSeconds($segundos)
    do {
        if(& $condicao){return}
        Start-Sleep -Milliseconds 350
    } until([datetime]::UtcNow -gt $limite)
    throw "Timeout: $descricao"
}
function Circuito {
    Invoke-RestMethod 'http://127.0.0.1:8082/circuit-breaker' -TimeoutSec 5
}
function Provedor {
    Invoke-RestMethod 'http://127.0.0.1:8090/provider/state' -TimeoutSec 5
}
function Aviso([guid]$id) {
    try { Invoke-RestMethod "http://127.0.0.1:8082/notifications/$id" -TimeoutSec 5 }
    catch { $null }
}
function Efeito([int]$porta,[guid]$id) {
    @(Invoke-RestMethod "http://127.0.0.1:$porta/effects?eventId=$id" -TimeoutSec 5)
}
function Publicar([string]$tipo) {
    $publicacao=& "$PSScriptRoot/disparar.ps1" -Tipo $tipo -Execucao $run
    if($publicacao.estado -ne 'PUBLICADO'){throw "Publicacao sem confirm: $tipo"}
    Registrar "PUBLICADO tipo=$tipo eventId=$($publicacao.eventId) attemptId=$($publicacao.attemptId)"
    [guid]$publicacao.eventId
}
function NovoAviso {
    $id=Publicar 'reserva.cancelada'
    Aguardar { (Aviso $id).estado -eq 'PENDING' } "aviso PENDING $id"
    $id
}
function Despachar([guid]$id) {
    $status=200
    try {
        $resposta=Invoke-RestMethod -Method Post "http://127.0.0.1:8082/notifications/$id/dispatch" -TimeoutSec 10
    } catch {
        if(!$_.Exception.Response){throw}
        $status=[int]$_.Exception.Response.StatusCode
        $resposta=$null
    }
    $aviso=Aviso $id
    $circuito=Circuito
    Registrar "DESPACHO eventId=$id http=$status aviso=$($aviso.estado) tentativasHttp=$($aviso.tentativasHttp) bloqueios=$($aviso.bloqueiosCircuito) circuito=$($circuito.state) providerCalls=$((Provedor).calls)"
    $resposta
}

trap {
    Registrar "FAIL $($_.Exception.Message)"
    throw $_
}

Registrar "E07 runId=$run UTC=$([datetime]::UtcNow.ToString('o'))"
$principais=@('retirada.queue','comunicacao.queue','manutencao.queue','auditoria.queue','preparacao.queue')
foreach($nome in $principais) {
    $q=Consultar-Api ("queues/rentflow/"+[uri]::EscapeDataString($nome))
    if($q.messages_ready -ne 0 -or $q.messages_unacknowledged -ne 0){throw "Fila principal ocupada: $nome"}
}
$estacionamentoAntes=(Consultar-Api 'queues/rentflow/rentflow.estacionamento').messages_ready
Registrar "BASELINE estacionamento=$estacionamentoAntes"

& "$PSScriptRoot/provedor.ps1" reset | Out-Null
Invoke-RestMethod -Method Post 'http://127.0.0.1:8082/circuit-breaker/reset' -TimeoutSec 5 | Out-Null
if((Circuito).state -ne 'CLOSED'){throw 'Circuito nao iniciou CLOSED'}

$normal=NovoAviso
Despachar $normal | Out-Null
if((Aviso $normal).estado -ne 'SENT' -or (Provedor).calls -ne 1 -or (Circuito).state -ne 'CLOSED'){
    throw 'Comunicacao normal nao confirmada'
}
Registrar "PASS normal eventId=$normal circuito=CLOSED providerCalls=1 estado=SENT"

# O sanity check nao participa da janela nem dos contadores principais do cenario.
& "$PSScriptRoot/provedor.ps1" reset | Out-Null
Invoke-RestMethod -Method Post 'http://127.0.0.1:8082/circuit-breaker/reset' -TimeoutSec 5 | Out-Null
$pendentes=@(1..5 | ForEach-Object { NovoAviso })
& "$PSScriptRoot/provedor.ps1" indisponivel | Out-Null

foreach($id in $pendentes[0..3]) {
    Despachar $id | Out-Null
}
$aberto=Circuito
$provedorAposFalhas=Provedor
if($aberto.state -ne 'OPEN' -or $provedorAposFalhas.calls -ne 4 -or $aberto.failedCalls -ne 4){
    throw 'Circuito nao abriu depois de quatro falhas'
}
Registrar "PASS aberto state=OPEN failedCalls=$($aberto.failedCalls) providerCalls=$($provedorAposFalhas.calls)"

$chamadasAntes=(Provedor).calls
Despachar $pendentes[4] | Out-Null
$bloqueado=Aviso $pendentes[4]
if((Provedor).calls -ne $chamadasAntes -or $bloqueado.tentativasHttp -ne 0 -or
        $bloqueado.bloqueiosCircuito -ne 1 -or (Circuito).state -ne 'OPEN'){
    throw 'Chamada bloqueada chegou ao provedor ou alterou tentativas HTTP'
}
Registrar "PASS bloqueada eventId=$($pendentes[4]) providerCalls=$chamadasAntes tentativasHttp=0 bloqueios=1"

$duranteAberto=Publicar 'reserva.confirmada'
Aguardar {
    (Aviso $duranteAberto).estado -eq 'PENDING' -and
    (Efeito 8081 $duranteAberto).Count -eq 1 -and
    (Efeito 8084 $duranteAberto).Count -eq 1 -and
    (Efeito 8085 $duranteAberto).Count -eq 1
} 'fluxo RabbitMQ durante OPEN'
if((Provedor).calls -ne 4){throw 'Publicacao RabbitMQ acionou HTTP automaticamente'}
Registrar "PASS fluxoDuranteOpen eventId=$duranteAberto retirada=1 comunicacao=PENDING auditoria=1 preparacao=1 providerCalls=4"

& "$PSScriptRoot/provedor.ps1" saudavel | Out-Null
$inicioEspera=[datetime]::UtcNow
do {
    Start-Sleep -Milliseconds 300
} until(([datetime]::UtcNow-$inicioEspera).TotalSeconds -ge 10.2)
if((Circuito).state -ne 'OPEN'){throw 'Transicao automatica inesperada antes da proxima chamada'}
Registrar 'PASS espera state=OPEN transicaoAutomatica=false'

Despachar $pendentes[0] | Out-Null
if((Circuito).state -ne 'HALF_OPEN' -or (Aviso $pendentes[0]).estado -ne 'SENT'){
    throw 'Primeira chamada de prova nao manteve HALF_OPEN'
}
Registrar "PASS halfOpenPrimeira eventId=$($pendentes[0]) state=HALF_OPEN"

Despachar $pendentes[1] | Out-Null
if((Circuito).state -ne 'CLOSED' -or (Aviso $pendentes[1]).estado -ne 'SENT'){
    throw 'Segunda chamada de prova nao fechou o circuito'
}
Registrar "PASS fechado eventId=$($pendentes[1]) state=CLOSED"

$restantes=@($pendentes[2],$pendentes[3],$pendentes[4],$duranteAberto)
foreach($id in $restantes) {
    Despachar $id | Out-Null
    if((Aviso $id).estado -ne 'SENT'){throw "Aviso nao enviado depois da recuperacao: $id"}
}
$final=Circuito
$provedorFinal=Provedor
$transicoes=$final.transitions | ForEach-Object { "$($_.origem)->$($_.destino)" }
if(($transicoes -join ',') -ne 'CLOSED->OPEN,OPEN->HALF_OPEN,HALF_OPEN->CLOSED'){
    throw "Transicoes divergentes: $transicoes"
}
if($provedorFinal.calls -ne 10 -or $provedorFinal.uniqueDelivered -ne 6){
    throw "Contadores finais divergentes: calls=$($provedorFinal.calls) unique=$($provedorFinal.uniqueDelivered)"
}
foreach($id in @($pendentes)+$duranteAberto) {
    if((Aviso $id).estado -ne 'SENT'){throw "Aviso final nao SENT: $id"}
}
$estacionamentoDepois=(Consultar-Api 'queues/rentflow/rentflow.estacionamento').messages_ready
if($estacionamentoDepois -ne $estacionamentoAntes){throw 'Fila de estacionamento foi alterada'}
Registrar "PASS final state=$($final.state) transitions=$($transicoes -join ',') providerCalls=$($provedorFinal.calls) uniqueDelivered=$($provedorFinal.uniqueDelivered) estacionamento=$estacionamentoDepois"
Registrar "PASS E07 runId=$run"
