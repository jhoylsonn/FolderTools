param(
    [string]$Version = "latest"
)

Write-Host "Instalando FolderTools (versão: $Version)..." -ForegroundColor Cyan

$zip = Join-Path $env:TEMP "FolderTools.zip"

if ($Version -eq "latest") {
    $url = "https://github.com/jhoylsonn/FolderTools/archive/refs/heads/main.zip"
}
else {
    $url = "https://github.com/jhoylsonn/FolderTools/archive/refs/tags/v$Version.zip"
}

Write-Host "Baixando: $url" -ForegroundColor Yellow

Invoke-WebRequest -Uri $url -OutFile $zip

$modulesPath = Join-Path $env:USERPROFILE "Documents\PowerShell\Modules"

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

$moduleFile = Join-Path $finalPath "FolderTools.psm1"

Import-Module $moduleFile -Force

Write-Host "FolderTools instalado e carregado com sucesso!" -ForegroundColor Green
