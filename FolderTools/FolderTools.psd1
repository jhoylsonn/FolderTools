@{
    RootModule        = 'FolderTools.psm1'
    ModuleVersion     = '5.9.1'
    GUID              = 'b7c1e8c3-9f4e-4f0a-9d8d-5c1f7a8c1234'
    Author            = 'Joilson'
    CompanyName       = 'Joilson'
    Description       = 'Ferramentas avançadas para análise de pastas, perfis de usuário e armazenamento no Windows.'

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

    PrivateData = @{
        PSData = @{
            Tags = @(
                'Folder',
                'Storage',
                'Disk',
                'Tools',
                'Windows',
                'Utility',
                'Analysis',
                'Size',
                'Management'
            )

            ProjectUri = 'https://www.powershellgallery.com/packages/FolderTools'
            LicenseUri = 'https://opensource.org/licenses/MIT'
            IconUri    = 'https://raw.githubusercontent.com/PowerShell/PowerShell/master/assets/ps_black_64.svg'

            ReleaseNotes = @'
Versão 5.9.1 — Correções e melhorias significativas:

• Correção completa do parâmetro -Full:
  - Pastas sempre aparecem antes dos arquivos, mesmo com -Sort.
  - Total agora soma apenas arquivos reais (sem duplicação).
  - Removida a contagem dupla causada por tamanhos recursivos.
  - Compatível com caminhos UNC e ambientes de rede.

• Melhorias no -All:
  - Lista somente pastas (raiz + recursivas).
  - Ignora junctions (ReparsePoints).
  - Total soma apenas pastas do primeiro nível.
  - Separação visual entre raiz e recursivas.

• Melhorias no -TotalAccurate:
  - Agora ignora junctions.
  - Respeita -Sort e -NoBytes.
  - Total idêntico ao Windows Explorer (somente arquivos).

• Melhorias gerais:
  - Filtro anti-junction aplicado em todos os modos.
  - Ordenação aprimorada.
  - Caminhos UNC tratados corretamente.
  - HELP atualizado para refletir todos os novos comportamentos.
'@
        }
    }
}