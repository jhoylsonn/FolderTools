# ==========================================
# Instalador interativo do modulo FolderTools
# ==========================================

Write-Host "Obtendo versoes disponiveis no GitHub..." -ForegroundColor Cyan

$tags = Invoke-RestMethod -Uri "https://api.github.com/repos/jhoylsonn/FolderTools/tags"
$versions = $tags.name

Write-Host ""
Write-Host "Versoes disponiveis:" -ForegroundColor Yellow

for ($i = 0; $i -lt $versions.Count; $i++) {
    Write-Host "[$($i+1)] $($versions[$i])"
}

Write-Host "[0] Ultima Versao (branch main)"
Write-Host ""

$choice = Read-Host "Digite o numero da versao que deseja instalar"

if ($choice -eq "0") {
    $Version = "latest"
}
else {
    $index = [int]$choice - 1
    $Version = $versions[$index].TrimStart("v")
}

Write-Host ""
Write-Host "Instalando FolderTools (versao: $Version)..." -ForegroundColor Cyan

$zip = Join-Path $env:TEMP "FolderTools.zip"

if ($Version -eq "latest") {
    $url = "https://github.com/jhoylsonn/FolderTools/archive/refs/heads/main.zip"
}
else {
    $url = "https://github.com/jhoylsonn/FolderTools/archive/refs/tags/v$Version.zip"
}

Write-Host "Baixando: $url" -ForegroundColor Yellow
Invoke-WebRequest -Uri $url -OutFile $zip

# INSTALACAO GLOBAL (igual instalador local)
$modulesPath = "C:\Program Files\WindowsPowerShell\Modules"

Expand-Archive $zip -DestinationPath $modulesPath -Force

if ($Version -eq "latest") {
    $downloadedPath = Join-Path $modulesPath "FolderTools-main\FolderTools"
    $folderToRemove = Join-Path $modulesPath "FolderTools-main"
}
else {
    $downloadedPath = Join-Path $modulesPath "FolderTools-$Version\FolderTools"
    $folderToRemove = Join-Path $modulesPath "FolderTools-$Version"
}

$finalPath = Join-Path $modulesPath "FolderTools"

if (Test-Path $finalPath) {
    Remove-Item $finalPath -Recurse -Force
}

Move-Item $downloadedPath $finalPath -Force

Remove-Item $folderToRemove -Recurse -Force
Remove-Item $zip -Force

# IMPORTAR VIA MANIFESTO (ESSENCIAL)
$manifest = Join-Path $finalPath "FolderTools.psd1"
Import-Module $manifest -Force

Write-Host ""
Write-Host "FolderTools instalado e carregado com sucesso!" -ForegroundColor Green
