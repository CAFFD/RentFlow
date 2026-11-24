param([Parameter(Mandatory)][guid]$EventId)
$ErrorActionPreference='Stop'
foreach ($porta in 8081..8085) {
    $resultado=Invoke-RestMethod "http://127.0.0.1:$porta/effects?eventId=$EventId" -TimeoutSec 5
    [pscustomobject]@{porta=$porta;eventId=$EventId;efeitos=$resultado}
}
