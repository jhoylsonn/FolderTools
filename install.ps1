# ==========================================
# Instalador interativo do modulo FolderTools
# ==========================================

Write-Host "Obtendo versoes disponiveis no GitHub..." -ForegroundColor Cyan

# Buscar tags (versoes) do repositorio
$tags = Invoke-RestMethod -Uri "https://api.github.com/repos/jhoylsonn/FolderTools/tags"

# Criar lista de versoes
$versions = $tags.name

Write-Host ""
Write-Host "Versoes disponiveis:" -ForegroundColor Yellow

# Mostrar lista numerada
for ($i = 0; $i -lt $versions.Count; $i++) {
    Write-Host "[$($i+1)] $($versions[$i])"
}

Write-Host "[0] Ultima Versao (branch main)"
Write-Host ""

# Perguntar ao usuario
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

# Caminho do ZIP temporario
$zip = Join-Path $env:TEMP "FolderTools.zip"

# Definir URL de download
if ($Version -eq "latest") {
    $url = "https://github.com/jhoylsonn/FolderTools/archive/refs/heads/main.zip"
}
else {
    $url = "https://github.com/jhoylsonn/FolderTools/archive/refs/tags/v$Version.zip"
}

Write-Host "Baixando: $url" -ForegroundColor Yellow
Invoke-WebRequest -Uri $url -OutFile $zip

# Caminho da pasta de modulos
$modulesPath = Join-Path $env:USERPROFILE "Documents\PowerShell\Modules"

# Extrair ZIP
Expand-Archive $zip -DestinationPath $modulesPath -Force

# Ajustar caminhos conforme versao
if ($Version -eq "latest") {
    $downloadedPath = Join-Path $modulesPath "FolderTools-main\FolderTools"
    $folderToRemove = Join-Path $modulesPath "FolderTools-main"
}
else {
    $downloadedPath = Join-Path $modulesPath "FolderTools-$Version\FolderTools"
    $folderToRemove = Join-Path $modulesPath "FolderTools-$Version"
}

# Caminho final
$finalPath = Join-Path $modulesPath "FolderTools"

# Remover versao antiga
if (Test-Path $finalPath) {
    Remove-Item $finalPath -Recurse -Force
}

# Mover modulo
Move-Item $downloadedPath $finalPath -Force

# Limpar temporarios
Remove-Item $folderToRemove -Recurse -Force
Remove-Item $zip -Force

# Importar modulo
$moduleFile = Join-Path $finalPath "FolderTools.psm1"
Import-Module $moduleFile -Force

Write-Host ""
Write-Host "FolderTools instalado e carregado com sucesso!" -ForegroundColor Green
