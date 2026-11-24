param([Parameter(Mandatory)][string]$Tipo, [string]$Execucao=([guid]::NewGuid().ToString()), [switch]$FalhaAposCommit, [int]$Porta=8080)
$ErrorActionPreference='Stop'
$id=[guid]::NewGuid().ToString()
$dados=@{runId=$Execucao; equipamentoId="EQ-$id"; equipamento='Gerador ficticio'}
switch -Wildcard ($Tipo) {
    'reserva.*' {
        $dados.reservaId="RES-$id"; $dados.cliente='Locadora Escola'
        if ($Tipo -eq 'reserva.confirmada') { $dados.retiradaInicio='2026-11-25T14:00:00Z'; $dados.retiradaFim='2026-11-25T16:00:00Z' }
    }
    'inspecao.*' {
        $dados.inspecaoId="INS-$id"
        if ($Tipo -eq 'inspecao.reprovada') { $dados.motivo='Freio em revisao'; $dados.destinatario='Oficina ficticia' }
        if ($Tipo -eq 'inspecao.agendada') { $dados.agendadaPara='2026-11-25T12:00:00Z' }
    }
}
if ($FalhaAposCommit) { $dados.testeFalhaAposCommit=$true }
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$Porta/events/$Tipo" -ContentType application/json -Body ($dados | ConvertTo-Json -Compress) -TimeoutSec 15
