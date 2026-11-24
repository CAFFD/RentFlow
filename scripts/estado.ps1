. "$PSScriptRoot/comum.ps1"
Compose ps --all
foreach ($servico in 'rabbitmq','postgres') {
    $id = Compose ps -q $servico
    if (!$id) { throw "$servico sem container ativo." }
    $saude = docker inspect --format '{{.State.Health.Status}}' $id
    if ($LASTEXITCODE -ne 0 -or $saude -ne 'healthy') { throw "$servico saude=$saude" }
}
$painel = Invoke-WebRequest -UseBasicParsing http://127.0.0.1:15672/ -TimeoutSec 8
"HTTP painel = $($painel.StatusCode)"
$pg = (Compose config --format json | Out-String | ConvertFrom-Json).services.postgres.environment
Compose exec -T postgres psql -U $pg.POSTGRES_USER -d $pg.POSTGRES_DB -v ON_ERROR_STOP=1 -c "SELECT 1"
