@{
    RootModule        = 'FolderTools.psm1'
    ModuleVersion     = '6.1.0'
    GUID              = 'b7c1e8c3-9f4e-4f0a-9d8d-5c1f7a8c1234'
    Author            = 'Joilson'
    CompanyName       = 'Joilson'
    Copyright         = '(c) 2026 Joilson. Todos os direitos reservados.'
    Description       = 'Ferramentas avancadas para analise de pastas, perfis de usuario e armazenamento no Windows.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    FunctionsToExport = @(
    'Get-FolderSize',
		'Get-DriveSize',
		'Get-StorageOverview',
		'Format-Size'
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
            Tags = @('foldersize','storage','disk','powershell','windows','unc','smb','top10','top20')
            ReleaseNotes = @'

  
  
Versao 6.1.0 - Performance & Stability Update
• Melhorias de performance:
- Implementado cache de tamanho de diretorios para evitar recalculo redundante
- Otimizacao do parametro -Top (Top10, Top20, Top N) com processamento incremental
- Reducao de uso de memoria em listagens grandes

• Melhorias de confiabilidade:
- Parametro -Resume agora informa quando itens nao puderam ser lidos
- Melhor tratamento silencioso de erros em ambientes com restricao de acesso

• Aprimoramentos internos:
- Otimizacoes aplicadas nos modos padrao, -All, -Full e -Recurse
- Nenhuma quebra de compatibilidade com versoes anteriores

• Observacoes:
- No modo -TotalAccurate, pastas sao listadas com tamanho 0 (somente arquivos compoem o total) 

 
 Versao 6.0
• Novos parametros -Top10, -Top20 e -Top N:
 - Adicionado -Top10 (atalho rapido para os 10 maiores itens)
 - Adicionado -Top20 (atalho rapido para os 20 maiores itens)
 - Adicionado -Top N (flexivel, permite qualquer numero, ex: -Top 15)
 - Top forca automaticamente ordenacao por tamanho
 - Aplicado em todos os modos: padrao, -All, -Recurse, -Full, -TotalAccurate
 - Mensagem clara indicando que TOTAL e soma apenas dos itens listados
 - Objetivo: listagem rapida sem processar todo o diretorio

 • Melhorias no parametro -Drivers (Get-DriveSize):
- Padronizacao do layout com colunas em GB no cabecalho e valores sem sufixo "GB"
- Inclusao da coluna "Root" com caminho completo (incluindo UNC em drives de rede)
- Melhor deteccao de drives de rede usando DisplayRoot
- Ordenacao padronizada: drives locais, depois rede e por ultimo "Temp"
- Inclusao da linha "Temp" como referencia informativa sem impacto de performance
- Ajustes visuais para melhor alinhamento e legibilidade do output

• Correcao de bug PropertyNotFoundException:
 - Corrigido erro quando pasta contem apenas arquivos (sem subpastas)
 - Validacao antes de Measure-Object em todos os modos
 - Pastas vazias agora retornam "TOTAL: 0 bytes" sem erros

• HELP atualizado:
 - Exemplos com -Top10, -Top20 e -Top N
 - Descricoes claras dos novos parametros

------------------------------------------------------------------------------------------ 

 Versao 5.9.3.5
• Novo Parametro -Resume para modo rapido:
 - Adicionado novo parametro: -Resume (modo rapido exibindo TOTAL | ARQUIVOS | PASTAS).
 - HELP atualizado com novas descricoes e exemplos.
 - Ajustes internos para suportar o novo modo sem afetar os modos existentes.
 - Mantida compatibilidade com PowerShell 5.1 e recomendacao de UTF-8 com BOM.            

------------------------------------------------------------------------------------------ 

 Versao 5.9.2 — Robustez, compatibilidade e regressao zero de layout:

• Robustez em UNC/rede:
  - Medicoes com try/catch e -ErrorAction Stop.
  - Itens com erro retornam 0 bytes sem interromper o processamento.

• Layout e modos restaurados (como 5.9.1):
  - -All volta a separar primeiro nivel x recursivas.
  - -TotalAccurate volta a listar tudo e total igual Explorer.
  - -Full volta a listar pastas primeiro e total soma apenas arquivos.
  - -Help volta a mostrar texto customizado.

-----------------------------------------------------------------------------------------

 Versao 5.9.1 — Melhorias significativas no calculo de tamanhos, precisao e organizacao:

• Novo comportamento do parametro -All:
  - Lista somente pastas (sem arquivos).
  - Ignora junctions (ReparsePoints).
  - Exibe pastas do primeiro nivel separadas das recursivas.
  - TOTAL agora soma apenas as pastas do primeiro nivel.

• Melhorias no -TotalAccurate:
  - Agora ignora junctions.
  - Respeita -NoBytes.
  - Respeita -Sort.
  - Mantem calculo exato igual ao Windows Explorer.

• Correcoes gerais:
  - Remocao completa de duplicacao de tamanhos.
  - Filtro anti-junction aplicado em todos os modos relevantes.
  - HELP atualizado para refletir todas as mudancas da versao 5.9.
------------------------------------------------------------
'@
        }
    }
}
