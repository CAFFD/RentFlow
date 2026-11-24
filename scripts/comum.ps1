$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
function Compose {
    & docker compose --project-name rentflow --project-directory $raiz --env-file "$raiz/.env" -f "$raiz/compose.yaml" @args
    if ($LASTEXITCODE -ne 0) { throw "Docker Compose falhou (codigo $LASTEXITCODE)." }
}

function Cabecalho-Local {
    $config = Compose config --format json | Out-String | ConvertFrom-Json
    $envBroker = $config.services.rabbitmq.environment
    $par = $envBroker.RABBITMQ_DEFAULT_USER + ':' + $envBroker.RABBITMQ_DEFAULT_PASS
    @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($par)) }
}

function Consultar-Api($rota) {
    Invoke-RestMethod -Uri ("http://127.0.0.1:15672/api/" + $rota) -Headers $cabecalho -TimeoutSec 8 -MaximumRedirection 0
}
