@{
    RootModule        = 'FolderTools.psm1'
    ModuleVersion     = '5.9.2'
    GUID              = 'b7c1e8c3-9f4e-4f0a-9d8d-5c1f7a8c1234'
    Author            = 'Joilson'
    CompanyName       = 'Joilson'
    Copyright         = '(c) 2026 Joilson. Todos os direitos reservados.'
    Description       = 'Ferramentas avancadas para analise de pastas, perfis de usuario e armazenamento no Windows.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    FunctionsToExport = @(
        'Get-FolderSize',
        'Format-Size',
        'Get-DriveSize',
        'Get-StorageOverview'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    RequiredModules   = @()
    RequiredAssemblies = @()

    ScriptsToProcess  = @()
    FileList          = @('FolderTools.psm1', 'FolderTools.psd1')

    PrivateData = @{
        PSData = @{
            Tags = @('foldersize','storage','disk','powershell','windows','unc','smb')
            ReleaseNotes = @'
Versao 5.9.1 — Melhorias significativas no calculo de tamanhos, precisao e organizacao:

• Novo comportamento do parametro -All:
  - Lista somente pastas (sem arquivos).
  - Ignora junctions (ReparsePoints) como "Meus Videos", "Minhas Imagens", etc.
  - Exibe pastas do primeiro nivel separadas das recursivas.
  - TOTAL agora soma apenas as pastas do primeiro nivel (sem duplicacao).
  - Suporte ao -Sort (Size/Name) mantendo a estrutura raiz -> recursivas.

• Melhorias no -TotalAccurate:
  - Agora ignora junctions.
  - Respeita -NoBytes.
  - Respeita -Sort.
  - Mantem calculo exato igual ao Windows Explorer (somando apenas arquivos reais).

• Correcoes gerais:
  - Remocao completa de duplicacao de tamanhos.
  - Filtro anti-junction aplicado em todos os modos relevantes.
  - HELP atualizado para refletir todas as mudancas da versao 5.9.

------------------------------------------------------------

Versao 5.9.2 — Robustez, compatibilidade e regressao zero de layout:

• Robustez em UNC/rede:
  - Medicoes com try/catch e -ErrorAction Stop.
  - Itens com erro retornam 0 bytes sem interromper o processamento.

• Layout e modos restaurados (como 5.9.1):
  - -All volta a separar primeiro nivel x recursivas.
  - -TotalAccurate volta a listar tudo e total igual Explorer.
  - -Full volta a listar pastas primeiro e total soma apenas arquivos.
  - -Help volta a mostrar texto customizado.
'@
        }
    }
}
