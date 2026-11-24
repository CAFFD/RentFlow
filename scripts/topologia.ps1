. "$PSScriptRoot/comum.ps1"
$cabecalho = Cabecalho-Local
$modelo = Get-Content -Raw "$raiz/infra/rabbitmq/definitions.json" | ConvertFrom-Json
$vhost = Consultar-Api 'vhosts/rentflow'
$x = Consultar-Api 'exchanges/rentflow/rentflow.events'
if ($vhost.name -ne 'rentflow' -or $x.type -ne 'topic' -or !$x.durable -or $x.auto_delete -or $x.internal) { throw 'Vhost ou exchange divergente.' }
$filas = @(Consultar-Api 'queues/rentflow' | ForEach-Object { $_ } | Where-Object name -ne 'rentflow.estacionamento')
if ($filas.Count -ne 5) { throw "Quantidade de filas: $($filas.Count)" }
foreach ($fila in $modelo.queues) {
    $q = $filas | Where-Object name -eq $fila.name
    if (!$q -or !$q.durable -or $q.exclusive -or $q.auto_delete -or $q.type -ne 'classic') { throw "Fila divergente: $($fila.name)" }
}
$b = Consultar-Api 'exchanges/rentflow/rentflow.events/bindings/source'
$real = @($b | ForEach-Object { "$($_.destination_type) $($_.destination) $($_.routing_key)" })
$esperado = @($modelo.bindings | ForEach-Object { "queue $($_.destination) $($_.routing_key)" })
if ($real.Count -ne 7 -or (Compare-Object $esperado $real)) { throw 'Bindings divergentes.' }
'PASS vhost=rentflow exchange=rentflow.events topic durable; 5 filas classic duraveis, nao exclusivas, sem auto-delete'
$real | Sort-Object
