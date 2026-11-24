. "$PSScriptRoot/comum.ps1"
$cabecalho=Cabecalho-Local
$filas=Consultar-Api 'queues/rentflow'
$filas | Sort-Object name | Select-Object name,messages_ready,messages_unacknowledged,consumers
