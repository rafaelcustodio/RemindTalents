<#
.SYNOPSIS
    Copia o addon RemindTalents deste repositorio para a instalacao do
    World of Warcraft (Retail).

.DESCRIPTION
    - Copia a raiz do repo para Interface\AddOns\RemindTalents.
    - NAO usa /PURGE (preserva qualquer arquivo extra ja presente no destino).
    - Exclui arquivos de desenvolvimento (.git, README, o proprio script).

.PARAMETER WowPath
    Caminho da instalacao Retail. Padrao: D:\Jogos\World of Warcraft\_retail_

.EXAMPLE
    .\copy-to-wow.ps1
    .\copy-to-wow.ps1 -WowPath "E:\WoW\_retail_"
#>
param(
    [string]$WowPath = "D:\Jogos\World of Warcraft\_retail_"
)

$ErrorActionPreference = "Stop"

$src    = $PSScriptRoot
$addons = Join-Path $WowPath "Interface\AddOns"
$dest   = Join-Path $addons "RemindTalents"

if (-not (Test-Path $addons)) {
    Write-Host "Pasta AddOns nao encontrada: $addons" -ForegroundColor Red
    Write-Host "Ajuste o parametro -WowPath." -ForegroundColor Red
    exit 1
}

$flags = @("/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/R:1", "/W:1")
$xf    = @(".gitignore", ".gitattributes", "README.md", "copy-to-wow.ps1", "settings.local.json")
$xd    = @((Join-Path $src ".git"), (Join-Path $src ".github"), (Join-Path $src ".claude"))

Write-Host "Origem : $src"
Write-Host "Destino: $dest`n"

$roboArgs = @($src, $dest) + $flags + @("/XF") + $xf + @("/XD") + $xd
robocopy @roboArgs | Out-Null

if ($LASTEXITCODE -ge 8) {
    Write-Host ("ERRO (codigo {0}) ao copiar." -f $LASTEXITCODE) -ForegroundColor Red
    exit 1
}

Write-Host "Concluido. Use /reload no jogo para aplicar." -ForegroundColor Green
exit 0
