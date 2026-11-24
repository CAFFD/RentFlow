. "$PSScriptRoot/comum.ps1"
$cfg = Compose config --format json | Out-String | ConvertFrom-Json
$pg = $cfg.services.postgres.environment
foreach ($arq in Get-ChildItem "$raiz/infra/sql/V*.sql" | Sort-Object Name) {
    if ($arq.Name -notmatch '^V[0-9]+__[a-z_]+\.sql$') { throw "Nome de migracao invalido" }
    $hash = (Get-FileHash $arq.FullName).Hash
    $sql = @"
BEGIN;
SELECT pg_advisory_xact_lock(725026);
CREATE SCHEMA IF NOT EXISTS rentflow_admin;
CREATE TABLE IF NOT EXISTS rentflow_admin.versoes (nome text PRIMARY KEY, hash text NOT NULL);
SELECT EXISTS(SELECT 1 FROM rentflow_admin.versoes WHERE nome='$($arq.Name)') AS aplicada \gset
\if :aplicada
SELECT 1 / (hash='$hash')::int FROM rentflow_admin.versoes WHERE nome='$($arq.Name)';
\else
$(Get-Content -Raw -Encoding UTF8 $arq.FullName)
INSERT INTO rentflow_admin.versoes VALUES ('$($arq.Name)','$hash');
\endif
COMMIT;
"@
    $sql | docker compose --project-directory $raiz -p rentflow -f "$raiz/compose.yaml" exec -T postgres psql -X -v ON_ERROR_STOP=1 -U $pg.POSTGRES_USER -d $pg.POSTGRES_DB
    if ($LASTEXITCODE) { throw "Migracao falhou: $($arq.Name)" }
}
& "$PSScriptRoot/acessos-db.ps1"
$cabecalho=Cabecalho-Local
$politicas=Consultar-Api 'policies/rentflow'
if (!($politicas | Where-Object name -eq 'falhas-nucleo')) {
    # Mensagens antigas com TTL seguiriam a nova DLX se expirassem depois da importacao.
    & "$PSScriptRoot/preflight.ps1"
}
Compose cp "$raiz/infra/rabbitmq/estacionamento.json" rabbitmq:/tmp/rentflow-estacionamento.json
Compose exec -T rabbitmq rabbitmqctl import_definitions /tmp/rentflow-estacionamento.json
$cabecalho = Cabecalho-Local
$limite=[datetime]::UtcNow.AddSeconds(45)
do {
    try {
        $b=Consultar-Api 'exchanges/rentflow/rentflow.falhas/bindings/source'
        $q=Consultar-Api 'queues/rentflow'
        if (@($b | Where-Object destination -eq 'rentflow.estacionamento').Count -eq 1 -and @($q | Where-Object policy -eq 'falhas-nucleo').Count -eq 5) { 'PASS estacionamento e politica nas cinco filas'; return }
    } catch { }
    Start-Sleep -Seconds 1
} until ([datetime]::UtcNow -gt $limite)
throw 'Estacionamento ou politica indisponivel'
