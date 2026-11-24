. "$PSScriptRoot/comum.ps1"
$cabecalho=Cabecalho-Local
$filas=Consultar-Api 'queues/rentflow'
$principais=@($filas | Where-Object name -like '*.queue')
if ($principais.Count -ne 5) { throw 'Esperadas cinco filas principais' }
foreach ($q in $principais) {
    "$($q.name) Ready=$($q.messages_ready) Unacked=$($q.messages_unacknowledged) Consumers=$($q.consumers)"
    if ($null -eq $q.messages_ready -or $null -eq $q.messages_unacknowledged -or $null -eq $q.consumers -or $q.messages_ready -ne 0 -or $q.messages_unacknowledged -ne 0 -or $q.consumers -ne 0) { throw 'Aguarde as filas vazias e sem consumidores antes da primeira partida.' }
}
'PASS linha de base vazia'
