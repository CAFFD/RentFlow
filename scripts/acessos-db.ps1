. "$PSScriptRoot/comum.ps1"
$cfg=Compose config --format json | Out-String | ConvertFrom-Json
$admin=$cfg.services.postgres.environment
$dir=Join-Path $raiz '.runtime'
[void][IO.Directory]::CreateDirectory($dir)
$arquivo=Join-Path $dir 'banco.json'
$schemas='producer','retirada','comunicacao','manutencao','auditoria','preparacao'
if (!(Test-Path -LiteralPath $arquivo)) {
    $senhas=[ordered]@{}
    foreach ($schema in $schemas) { $senhas[$schema]=[guid]::NewGuid().ToString('N') }
    $novo=[IO.File]::Open($arquivo,'CreateNew','Write','None')
    try { $bytes=[Text.Encoding]::UTF8.GetBytes(($senhas | ConvertTo-Json)); $novo.Write($bytes,0,$bytes.Length) }
    finally { $novo.Dispose() }
}
$senhas=Get-Content -Raw $arquivo | ConvertFrom-Json
foreach ($schema in $schemas) {
    $login="rentflow_app_$schema"
    $senha=$senhas.$schema
    if ($senha -notmatch '^[a-f0-9]{32}$') { throw "Credencial local invalida: $schema" }
    # Senha enviada pelo stdin do psql; o terminal exibe somente o resultado.
    $sql=@"
BEGIN;
SELECT pg_advisory_xact_lock(725026);
SELECT NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='$login') AS criar \gset
\if :criar
CREATE ROLE $login LOGIN PASSWORD '$senha';
\endif
GRANT USAGE ON SCHEMA $schema TO $login;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA $schema TO $login;
"@
    if ($schema -eq 'producer') { $sql += "`nGRANT UPDATE (estado,motivo,concluida) ON producer.tentativas TO $login;" }
    $sql += "`nCOMMIT;"
    $sql | docker compose --project-directory $raiz -p rentflow -f "$raiz/compose.yaml" exec -T postgres psql -X -q -v ON_ERROR_STOP=1 -U $admin.POSTGRES_USER -d $admin.POSTGRES_DB > $null
    if ($LASTEXITCODE) { throw "Permissoes falharam para $schema" }
}
'PASS permissoes concedidas por schema'
