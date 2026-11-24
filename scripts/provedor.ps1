param(
    [ValidateSet('iniciar','estado','parar','reset','saudavel','indisponivel')] [string]$Acao='estado'
)
$ErrorActionPreference='Stop'
$raiz=Split-Path $PSScriptRoot -Parent
$dir=Join-Path $raiz '.runtime'
[void][IO.Directory]::CreateDirectory($dir)
$registro=Join-Path $dir 'notification-provider.json'
$jar=(Get-Item "$raiz/tools/mock-notification-provider/target/mock-notification-provider-0.1.0-SNAPSHOT.jar").FullName
$atual=$null
if(Test-Path $registro) {
    $reg=Get-Content -Raw $registro | ConvertFrom-Json
    $proc=Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$reg.pid)"
    if($proc -and $proc.Name -eq 'java.exe' -and $proc.CommandLine.Contains($jar) -and
            $proc.CommandLine.Contains("-Drentflow.provider=$($reg.token) ")) {
        $atual=$proc
    }
}
if($Acao -eq 'parar') {
    if($atual) {
        $processo=Get-Process -Id $atual.ProcessId -ErrorAction Stop
        Stop-Process -InputObject $processo -ErrorAction Stop
        if(!$processo.WaitForExit(10000)){throw 'Provedor ainda em execucao'}
    }
    'notification-provider parado'
    return
}
if($Acao -eq 'iniciar') {
    if($atual) { 'notification-provider ja ativo'; return }
    if([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().Port -contains 8090) {
        throw 'Porta 8090 ocupada'
    }
    $jdk=[Environment]::GetEnvironmentVariable('JAVA_HOME','Machine')
    $java=Join-Path $jdk 'bin/java.exe'
    if(!(Test-Path $java)){$java=(Get-Command java.exe).Source}
    $token=[guid]::NewGuid().ToString()
    $log=Join-Path $dir "notification-provider-$token"
    $args=@('--add-modules','jdk.httpserver',"-Drentflow.provider=$token",'-jar',("`"$jar`""),'8090')
    $p=Start-Process $java -ArgumentList $args -WorkingDirectory $raiz -WindowStyle Hidden -RedirectStandardOutput "$log.log" -RedirectStandardError "$log.err" -PassThru
    @{pid=$p.Id;token=$token;porta=8090;log="$log.log"} | ConvertTo-Json | Set-Content $registro
    $limite=[datetime]::UtcNow.AddSeconds(30)
    do {
        if($p.HasExited){throw "Provedor encerrou; consulte $log.err"}
        try{$estado=Invoke-RestMethod 'http://127.0.0.1:8090/provider/state' -TimeoutSec 2;break}catch{}
        Start-Sleep -Milliseconds 300
    } until([datetime]::UtcNow -gt $limite)
    if(!$estado){throw 'Provedor nao respondeu'}
    "notification-provider pid=$($p.Id) porta=8090 mode=$($estado.mode)"
    return
}
if(!$atual){throw 'notification-provider OFFLINE'}
$rotas=@{
    estado=@{metodo='GET';rota='state'}
    reset=@{metodo='POST';rota='reset'}
    saudavel=@{metodo='POST';rota='mode/healthy'}
    indisponivel=@{metodo='POST';rota='mode/unavailable'}
}
$op=$rotas[$Acao]
Invoke-RestMethod -Method $op.metodo -Uri "http://127.0.0.1:8090/provider/$($op.rota)" -TimeoutSec 5
