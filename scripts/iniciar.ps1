. "$PSScriptRoot/comum.ps1"
if (!(Test-Path -LiteralPath "$raiz/.env")) {
    $modelo = Get-Content -Raw -Encoding UTF8 "$raiz/.env.example"
    $modelo = $modelo -replace '(?m)^POSTGRES_PASSWORD=[^\r\n]+', ('POSTGRES_PASSWORD=' + [guid]::NewGuid().ToString('N'))
    $modelo = $modelo -replace '(?m)^RABBITMQ_DEFAULT_PASS=[^\r\n]+', ('RABBITMQ_DEFAULT_PASS=' + [guid]::NewGuid().ToString('N'))
    $arquivo = [IO.File]::Open("$raiz/.env", 'CreateNew', 'Write', 'None')
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($modelo)
        $arquivo.Write($bytes, 0, $bytes.Length)
    } finally { $arquivo.Dispose() }
}
Compose config --quiet
Compose up -d --wait --wait-timeout 150 rabbitmq postgres
Compose exec -T rabbitmq rabbitmqctl import_definitions /etc/rabbitmq/rentflow.json
$limite = [datetime]::UtcNow.AddSeconds(45)
while ($true) {
    try {
        & "$PSScriptRoot/topologia.ps1"
        break
    } catch {
        if ([datetime]::UtcNow -ge $limite) { throw }
        Start-Sleep -Seconds 2
    }
}
& "$PSScriptRoot/estado.ps1"
