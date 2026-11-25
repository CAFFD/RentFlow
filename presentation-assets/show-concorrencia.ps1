$ErrorActionPreference = 'Stop'
$evidence = Join-Path (Split-Path $PSScriptRoot -Parent) 'docs/evidencias/exp-nucleo-2d25e89d-2c75-4acd-acb1-e48579033b55.txt'
$workerA = (Select-String -LiteralPath $evidence -Pattern '^Worker-A tarefas=' | Select-Object -First 1).Line
$workerB = (Select-String -LiteralPath $evidence -Pattern '^Worker-B tarefas=' | Select-Object -First 1).Line
$pass = (Select-String -LiteralPath $evidence -Pattern '^PASS concorrencia ' | Select-Object -First 1).Line
if (!$workerA -or !$workerB -or !$pass) { throw 'Evidencia de concorrencia incompleta.' }

$countA = [int]([regex]::Match($workerA, 'tarefas=(\d+)').Groups[1].Value)
$countB = [int]([regex]::Match($workerB, 'tarefas=(\d+)').Groups[1].Value)
$total = $countA + $countB

function Line([string]$text, [ConsoleColor]$color = [ConsoleColor]::Gray) {
    Write-Host $text -ForegroundColor $color
}

Line '=============================================================================='
Line ' RENTFLOW | TESTE REAL DE CONCORRENCIA' Cyan
Line ' Uma fila de preparacao, dois processos independentes' DarkCyan
Line '=============================================================================='
Line ''
Line '                 10 RESERVAS PUBLICADAS' White
Line '                          |'
Line '                          v'
Line '                 preparacao.queue' Yellow
Line '                    /           \'
Line '                   v             v'
Line ("          Worker-A  [{0}{1}]  {2}" -f ('#' * $countA),('.' * (10-$countA)),$countA) Green
Line ("          Worker-B  [{0}{1}]  {2}" -f ('#' * $countB),('.' * (10-$countB)),$countB) Green
Line ''
Line " RESULTADO | $total tarefas unicas persistidas" White
Line ' REGRA     | a divisao nao precisa ser igual' DarkGray
Line ''
Line " $pass" Green
Line '=============================================================================='
Line ' FONTE | exp-nucleo-2d25e89d-2c75-4acd-acb1-e48579033b55.txt' DarkGray
