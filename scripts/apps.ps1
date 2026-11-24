param(
    [ValidateSet('iniciar','estado','parar')] [string]$Acao='estado',
    [ValidateSet('todos','producer','retirada','comunicacao','manutencao','auditoria','Worker-A','Worker-B')] [string]$Nome='todos',
    [switch]$TesteFalha,
    [int]$Porta
)
. "$PSScriptRoot/comum.ps1"
$portas=[ordered]@{producer=8080;retirada=8081;comunicacao=8082;manutencao=8083;auditoria=8084;'Worker-A'=8085;'Worker-B'=8086}
if ($Porta -and ($Nome -eq 'todos' -or $Porta -lt 1 -or $Porta -gt 65535)) { throw 'Porta individual invalida' }
if ($TesteFalha -and $Nome -ne 'retirada') { throw 'Gancho exclusivo da retirada' }
$dir=Join-Path $raiz '.runtime'
[void][IO.Directory]::CreateDirectory($dir)
if ($Acao -eq 'iniciar') {
    $cfg=Compose config --format json | Out-String | ConvertFrom-Json
    $dbNome=$cfg.services.postgres.environment.POSTGRES_DB
    $brokerUser=$cfg.services.rabbitmq.environment.RABBITMQ_DEFAULT_USER
    $brokerPass=$cfg.services.rabbitmq.environment.RABBITMQ_DEFAULT_PASS
    $senhas=Get-Content -Raw (Join-Path $dir 'banco.json') | ConvertFrom-Json
    $jdk=[Environment]::GetEnvironmentVariable('JAVA_HOME','Machine')
    $java=Join-Path $jdk 'bin/java.exe'
    if (!(Test-Path $java)) { $java=(Get-Command java.exe).Source }
}
$lista=if ($Nome -eq 'todos') { $portas.Keys } else { $Nome }
foreach ($instancia in $lista) {
    $modulo=$instancia
    if ($instancia -like 'Worker-*') { $modulo='preparacao' }
    $pasta=if ($modulo -eq 'producer') { 'producer' } else { "consumers/$modulo" }
    $jar=(Get-Item "$raiz/$pasta/target/$modulo-0.1.0-SNAPSHOT.jar").FullName
    $registro=Join-Path $dir "$instancia.json"
    $atual=$null
    if (Test-Path $registro) {
        $reg=Get-Content -Raw $registro | ConvertFrom-Json
        $proc=Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$reg.pid)"
        if ($proc -and $proc.Name -eq 'java.exe' -and $proc.CommandLine.Contains($jar) -and $proc.CommandLine.Contains("-Drentflow.exec=$($reg.token) ")) { $atual=$proc }
    }
    if ($Acao -eq 'parar') {
        if ($atual) {
            $alvo=Get-Process -Id $atual.ProcessId -ErrorAction Stop
            Stop-Process -InputObject $alvo -ErrorAction Stop
            if (!$alvo.WaitForExit(15000)) { throw "$instancia ainda em execucao" }
        }
        "$instancia parado"; continue
    }
    if ($Acao -eq 'estado') {
        if (!$atual) { "$instancia OFFLINE"; continue }
        $health=Invoke-RestMethod "http://127.0.0.1:$($reg.porta)/actuator/health" -TimeoutSec 5
        "$instancia pid=$($reg.pid) porta=$($reg.porta) health=$($health.status)"; continue
    }
    if ($atual) {
        if (($Porta -and $Porta -ne $reg.porta) -or ([bool]$TesteFalha -ne $atual.CommandLine.Contains('--rentflow.teste-falha=true'))) {
            throw "$instancia ja ativo com outra configuracao"
        }
        $saude=Invoke-RestMethod "http://127.0.0.1:$($reg.porta)/actuator/health" -TimeoutSec 5
        if ($saude.status -ne 'UP') { throw "$instancia ja ativo e sem saude" }
        "$instancia ja ativo na porta $($reg.porta)"; continue
    }
    $port=$portas[$instancia]
    if ($Porta) { $port=$Porta }
    if ([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().Port -contains $port) { throw "Porta $port ocupada" }
    $token=[guid]::NewGuid().ToString()
    $log=Join-Path $dir "$instancia-$token"
    $argumentos=@('-Xms24m','-Xmx96m','-XX:ActiveProcessorCount=2',"-Drentflow.exec=$token",'-jar',("`"$jar`""),"--server.port=$port")
    if ($TesteFalha) { $argumentos+='--rentflow.teste-falha=true' }
    $escopo=@{
        WORKER_ID=$instancia; POSTGRES_DB=$dbNome; POSTGRES_USER="rentflow_app_$modulo";
        POSTGRES_PASSWORD=$senhas.$modulo; RABBITMQ_DEFAULT_USER=$brokerUser; RABBITMQ_DEFAULT_PASS=$brokerPass
    }
    $anteriores=@{}
    try {
        foreach ($chave in $escopo.Keys) {
            $anteriores[$chave]=[Environment]::GetEnvironmentVariable($chave,'Process')
            [Environment]::SetEnvironmentVariable($chave,$escopo[$chave],'Process')
        }
        $p=Start-Process $java -ArgumentList $argumentos -WorkingDirectory $raiz -WindowStyle Hidden -RedirectStandardOutput "$log.log" -RedirectStandardError "$log.err" -PassThru
    } finally {
        foreach ($chave in $anteriores.Keys) { [Environment]::SetEnvironmentVariable($chave,$anteriores[$chave],'Process') }
    }
    @{pid=$p.Id;token=$token;porta=$port;log="$log.log"} | ConvertTo-Json | Set-Content $registro
    $limite=[datetime]::UtcNow.AddSeconds(90)
    do {
        if ($p.HasExited) { throw "$instancia encerrou; consulte $log.log" }
        try { $h=Invoke-RestMethod "http://127.0.0.1:$port/actuator/health" -TimeoutSec 3; if ($h.status -eq 'UP') { break } } catch { }
        Start-Sleep -Milliseconds 500
    } until ([datetime]::UtcNow -gt $limite)
    if ($h.status -ne 'UP' -or [datetime]::UtcNow -gt $limite) { throw "$instancia nao saudavel" }
    "$instancia pid=$($p.Id) porta=$port UP"
}
