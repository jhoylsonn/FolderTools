# ================================
# Instalação do módulo FolderTools
# ================================

Write-Host "Baixando módulo FolderTools do GitHub..." -ForegroundColor Cyan

# Caminho do ZIP temporário
$zip = Join-Path $env:TEMP "FolderTools.zip"

# Baixar o repositório (branch main)
Invoke-WebRequest `
    -Uri "https://github.com/jhoylsonn/FolderTools/archive/refs/heads/main.zip" `
    -OutFile $zip

Write-Host "Download concluido." -ForegroundColor Green

# Caminho da pasta de módulos do usuário
$modulesPath = Join-Path $env:USERPROFILE "Documents\PowerShell\Modules"

# Extrair o ZIP
Expand-Archive $zip -DestinationPath $modulesPath -Force

# Caminho da pasta baixada
$downloadedPath = Join-Path $modulesPath "FolderTools-main\FolderTools"

# Caminho final do módulo
$finalPath = Join-Path $modulesPath "FolderTools"

# Se já existir uma versão antiga, remover
if (Test-Path $finalPath) {
    Remove-Item $finalPath -Recurse -Force
}

# Mover o módulo para o local correto
Move-Item $downloadedPath $finalPath -Force

# Remover pasta extra criada pelo GitHub
Remove-Item (Join-Path $modulesPath "FolderTools-main") -Recurse -Force

# Remover ZIP temporário
Remove-Item $zip -Force

Write-Host "Modulo instalado em: $finalPath" -ForegroundColor Green

# Importar o módulo usando caminho absoluto
$moduleFile = Join-Path $finalPath "FolderTools.psm1"

Import-Module $moduleFile -Force

Write-Host "FolderTools carregado com sucesso!" -ForegroundColor Green
