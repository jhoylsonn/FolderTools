<#
    FOLDERTOOLS 6.1 - HELP (Performance & Stability Update)
    Autor: Joilson Michell
    Descricao: Ferramentas avancadas para analise de pastas, perfis e armazenamento.

    Novidades versao 6.0:
    - Adicionados parametros -Top10, -Top20 e -Top N para listagem rapida dos maiores itens
    - Corrigido bug PropertyNotFoundException quando pasta contem apenas arquivos
    - Top10/Top20 aplicado em todos os modos (padrao, -All, -Recurse, -Full, -TotalAccurate)
    - Mensagem clara no TOTAL indicando que soma e apenas dos itens listados
    - Help atualizado com novos parametros

    Objetivo desta revisao:
    - Restaurar o comportamento e layout da 5.9.1 (Print-Row/Write-Host), incluindo:
      * -All com separacao "PASTAS DO PRIMEIRO NIVEL" e "PASTAS RECURSIVAS"
      * -TotalAccurate (GUI mode) listando TUDO (pastas + arquivos) com total igual Explorer (somente arquivos)
      * -Full (pastas primeiro + arquivos depois) e TOTAL = soma dos arquivos
      * -Resume (Para Calculo de Tamanho Rapido sem Print List)
    - Manter as melhorias de robustez para UNC/rede:
      * Medicoes com try/catch + -ErrorAction Stop para evitar spam de erros
      * Itens com erro retornam 0 bytes sem interromper o processamento

    Compatibilidade PS 5.1:
    - Evita caracteres especiais (usa ASCII).
    - Recomenda-se salvar este arquivo em UTF-8 com BOM.
#>

Set-StrictMode -Version Latest

function Format-Size {
    param([long]$bytes)
    if ($bytes -eq $null) { return "0 bytes" }
    if ($bytes -ge 1TB) { return ("{0:N2} TB" -f ($bytes / 1TB)) }
    if ($bytes -ge 1GB) { return ("{0:N2} GB" -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ("{0:N2} MB" -f ($bytes / 1MB)) }
    if ($bytes -ge 1KB) { return ("{0:N2} KB" -f ($bytes / 1KB)) }
    return "$bytes bytes"
}

function Split-Size {
    param([string]$Formatted)

    $Formatted = ($Formatted -as [string]).Trim() -replace "\s+", " "

    if ($Formatted -match "^([\d\.,]+)\s+(\w+)$") {
        return @{ Number = $matches[1]; Unit = $matches[2] }
    }

    return @{ Number = $Formatted; Unit = "bytes" }
}

function Print-Row {
    param(
        $Mode,
        $Tamanho,
        $UN,
        $Bytes,
        $Tipo,
        $Nome,
        [switch]$NoBytes
    )

    if ($NoBytes) {
        Write-Host ($Mode.PadRight(6)) `
                   ($Tamanho.PadRight(10)) `
                   ($UN.PadRight(6)) `
                   ($Tipo.PadRight(20)) `
                   $Nome
    }
    else {
        Write-Host ($Mode.PadRight(6)) `
                   ($Tamanho.PadRight(10)) `
                   ($UN.PadRight(6)) `
                   ($Bytes.ToString().PadRight(12)) `
                   ($Tipo.PadRight(20)) `
                   $Nome
    }
}

function Get-DriveSize {

    function _FmtGbCell([long]$bytes) {
        if ($bytes -le 0) { return "0 bytes" }
        return ("{0:N2}" -f ($bytes / 1GB))
    }
    function _ShortRoot([string]$root, [int]$max = 38) {
        if ([string]::IsNullOrWhiteSpace($root)) { return "" }
        if ($root.Length -le $max) { return $root }
        return ($root.Substring(0, $max - 1) + "â€¦")
    }

    $drives = Get-PSDrive -PSProvider FileSystem

    $rows = foreach ($d in $drives) {

        # âœ… ROOT "real": para mapeados, DisplayRoot geralmente traz o UNC.
        # Fallback para Root quando DisplayRoot vier vazio.
        $rootReal = $null
        try { $rootReal = $d.DisplayRoot } catch { $rootReal = $null }
        if ([string]::IsNullOrWhiteSpace($rootReal)) { $rootReal = $d.Root }

        $total = $d.Used + $d.Free
        $used  = [long]$d.Used
        $free  = [long]$d.Free
        $pct   = if ($total -gt 0) { [math]::Round(($used / $total) * 100) } else { 0 }

        $tipo = "Desconhecido"
        $cat  = 0  # 0 = Local, 1 = Network

        # âœ… Detecta Network de forma mais correta usando rootReal (UNC)
        if ($rootReal -like "\\*") {
            $tipo = "Network"
            $cat  = 1
        }
        else {
            try {
                $tipo = (New-Object System.IO.DriveInfo($d.Root)).DriveType.ToString()
            } catch {
                $tipo = "Desconhecido"
            }
            $cat = 0
        }

        [PSCustomObject]@{
            Drive = $d.Name
            Total = _FmtGbCell $total
            Usado = _FmtGbCell $used
            Livre = _FmtGbCell $free
            Pct   = ("{0}%" -f $pct)
            Tipo  = $tipo
            Root  = _ShortRoot $rootReal
            _Cat  = $cat
        }
    }

    $rows = $rows | Sort-Object _Cat, @{ Expression = "Drive"; Ascending = $true }

    # Linha Temp como referencia informativa
    $tempPath = $env:TEMP
    if ($tempPath) {
        $tempDrive = $null
        if ($tempPath -match "^(?<dl>[A-Za-z]):\\") {
            $tempDrive = $matches.dl.ToUpper()
        }

        if ($tempDrive) {
            $ref = $rows | Where-Object { $_.Drive -eq $tempDrive } | Select-Object -First 1
            if ($ref) {
                $rows = @($rows) + [PSCustomObject]@{
                    Drive = "Temp"
                    Total = $ref.Total
                    Usado = $ref.Usado
                    Livre = $ref.Livre
                    Pct   = $ref.Pct
                    Tipo  = $ref.Tipo
                    Root  = _ShortRoot $tempPath
                    _Cat  = 2
                }
            }
        }
        else {
            $rows = @($rows) + [PSCustomObject]@{
                Drive = "Temp"
                Total = "0 bytes"
                Usado = "0 bytes"
                Livre = "0 bytes"
                Pct   = "0%"
                Tipo  = "Network"
                Root  = _ShortRoot $tempPath
                _Cat  = 2
            }
        }
    }

    Write-Host "Drive  Total(GB)    Usado(GB)    Livre(GB)   %Usado   Tipo       Root"
    Write-Host "-----  -----------  -----------  -----------  ------   ------     ------"

    foreach ($r in $rows) {
        Write-Host ($r.Drive.ToString().PadRight(5)) `
                  ($r.Total.ToString().PadRight(12)) `
                  ($r.Usado.ToString().PadRight(12)) `
                  ($r.Livre.ToString().PadRight(12)) `
                  ($r.Pct.ToString().PadRight(7)) `
                  ($r.Tipo.ToString().PadRight(10)) `
                  $r.Root
    }
}

function Get-StorageOverview {
    param([string]$UserPath = $null)

    if ($UserPath) { $UserPath = $UserPath.TrimEnd("\") }

    if ($UserPath) {
        $resolved = Resolve-Path $UserPath -ErrorAction SilentlyContinue
        if (-not $resolved) { Write-Host "Caminho invalido: $UserPath"; return }
        $UserPath = $resolved.Path
        $Drive = $UserPath.Substring(0,1)
    }
    else {
        $Drive = "C"
    }

    $d = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ieq $Drive }
    if (-not $d) { Write-Host "Unidade '$Drive' nao encontrada."; return }

    $total = $d.Used + $d.Free
    $used  = $d.Used
    $free  = $d.Free
    $root  = "$Drive`:"

    if ($UserPath) {
        $userName = Split-Path $UserPath -Leaf
        $userBase = "C:\Users\$userName"
    }
    else {
        $userBase = "C:\Users\$env:USERNAME"
    }

    $docs   = Join-Path $userBase "Documents"
    $desk   = Join-Path $userBase "Desktop"
    $temp   = Join-Path $userBase "AppData\Local\Temp"

    $win    = Join-Path $root "Windows"
    $pgm    = Join-Path $root "Program Files"
    $pgm86  = Join-Path $root "Program Files (x86)"
    $pdata  = Join-Path $root "ProgramData"

    function Sum-Folder([string]$path) {
        try {
            if (Test-Path -LiteralPath $path -ErrorAction Stop) {
                $sum = (Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction Stop |
                        Measure-Object Length -Sum).Sum
                if ($sum -eq $null) { return 0 }
                return [long]$sum
            }
        } catch { return 0 }
        return 0
    }

    $sizeWin   = Sum-Folder $win
    $sizePgm   = Sum-Folder $pgm
    $sizePgm86 = Sum-Folder $pgm86
    $sizePData = Sum-Folder $pdata
    $sizeDocs  = Sum-Folder $docs
    $sizeDesk  = Sum-Folder $desk
    $sizeTemp  = Sum-Folder $temp

    $sizeSistema = $sizeWin + $sizePData
    $sizeApps    = $sizePgm + $sizePgm86
    $sumKnown = $sizeSistema + $sizeApps + $sizeDocs + $sizeDesk + $sizeTemp
    $sizeOther = [math]::Max([decimal]0, ([decimal]$used - [decimal]$sumKnown))

    Write-Host "======================"
    Write-Host "   STORAGE OVERVIEW"
    Write-Host "======================"
    Write-Host ""
    Write-Host "Disco: $root\"
    Write-Host ("Total: " + (Format-Size $total))
    Write-Host ("Usado: " + (Format-Size $used))
    Write-Host ("Livre: " + (Format-Size $free))
    Write-Host "----------------------"
    Write-Host ""
    Write-Host "Perfil analisado: $userBase"
    Write-Host ""
    Write-Host "Categorias:"
    Write-Host "----------------------------------------------"
    Write-Host ("{0,-28} {1}" -f "Sistema e reservado", (Format-Size $sizeSistema))
    Write-Host ("{0,-28} {1}" -f "Aplicativos instalados", (Format-Size $sizeApps))
    Write-Host ("{0,-28} {1}" -f "Documentos", (Format-Size $sizeDocs))
    Write-Host ("{0,-28} {1}" -f "Arquivos temporarios", (Format-Size $sizeTemp))
    Write-Host ("{0,-28} {1}" -f "Outros", (Format-Size $sizeOther))
    Write-Host ("{0,-28} {1}" -f "Area de Trabalho", (Format-Size $sizeDesk))
    Write-Host "----------------------------------------------"
    Write-Host ""
}


function Add-TopResult {
    param (
        [array]$TopList,
        [object]$Item,
        [int]$Limit
    )

    if ($TopList.Count -lt $Limit) {
        return $TopList + $Item
    }

    $min = $TopList | Sort-Object Size | Select-Object -First 1

    if ($Item.Size -gt $min.Size) {
        $TopList = $TopList | Where-Object { $_.Path -ne $min.Path }
        return $TopList + $Item
    }

    return $TopList
}

function Get-FolderSize {
    param(
        [string]$Path = ".",
        [switch]$All,
        [switch]$Recurse,
        [switch]$Full,
        [switch]$Drivers,
        [switch]$NoBytes,
        [switch]$Overview,
        [switch]$Help,
        [switch]$TotalAccurate,
        [switch]$Resume,
        [switch]$Top10,
        [switch]$Top20,
        [int]$Top = 0,
        [string]$Sort
    )

    # HELP customizado
    if ($Help) {
        Write-Host "========================================================="
        Write-Host "FOLDERTOOLS 6.1 - HELP (Performance & Stability Update)"
        Write-Host "========================================================="
        Write-Host ""
        Write-Host "Get-FolderSize                       - Lista as pastas do diretorio atual"
        Write-Host "                                       (primeiro nivel, sem recursao)"
        Write-Host "Get-FolderSize -All                  - Lista somente pastas (raiz + recursivas)"
        Write-Host "                                       Total = soma das pastas do primeiro nivel"
        Write-Host "Get-FolderSize -Recurse              - Lista todos os arquivos recursivamente"
        Write-Host "Get-FolderSize -Full                 - Lista pastas + arquivos (pastas primeiro)"
        Write-Host "                                       Total = soma dos arquivos (sem duplicacao)"
        Write-Host "Get-FolderSize -TotalAccurate        - Modo GUI (pastas + arquivos, total exato)"
        Write-Host "                                       Observacao: Pastas sao listadas com tamanho 0"
        Write-Host "                                       (somente arquivos somam no total)"
        Write-Host "Get-FolderSize -Resume               - Mostra somente TOTAL(Recursivo) | ARQUIVOS | PASTAS"
        Write-Host "                                       Exibe aviso quando itens não puderem ser lidos"
        Write-Host "                                       (acesso negado, etc.)"
        Write-Host "Get-FolderSize -Top10                - Lista os 10 maiores itens"
        Write-Host "Get-FolderSize -Top20                - Lista os 20 maiores itens"
        Write-Host "Get-FolderSize -Top 15               - Lista os N maiores itens (flexivel)"
        Write-Host "                                       Observacao: O TOTAL reflete apenas os itens exibidos"
        Write-Host "Get-FolderSize -Sort Size            - Ordena por tamanho"
        Write-Host "Get-FolderSize -Sort Name            - Ordena por nome"
        Write-Host "Get-FolderSize -NoBytes              - Oculta a coluna Bytes"
        Write-Host "Get-FolderSize -Drivers              - Mostra informacoes dos discos"
        Write-Host "Get-FolderSize -Overview             - Resumo estilo Windows 10/11"
        Write-Host "Get-StorageOverview                  - Resumo estilo Windows 10/11"
        Write-Host "Get-DriveSize                        - Mostra informacoes dos discos"
        Write-Host ""
        Write-Host "Exemplos:"
        Write-Host ""
        Write-Host "Get-FolderSize C:\Users\Joilson\Documents"
        Write-Host "Get-FolderSize C:\ -Sort Size"
        Write-Host "Get-FolderSize -Full -Sort Size -NoBytes"
        Write-Host "Get-FolderSize -TotalAccurate C:\Users\Joilson\Documents"
        Write-Host "Get-FolderSize -All C:\Users\Joilson\Documents -Sort Size"
        Write-Host "Get-FolderSize C:\ -Top10"
        Write-Host "Get-FolderSize -Recurse -Top 25"
        Write-Host ""
        return
    }

    if ($Overview) { Get-StorageOverview $Path; return }
    if ($Drivers) { Get-DriveSize; return }

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolved) { Write-Host "Caminho invalido: $Path"; return }
    $Path = $resolved.Path

    # Validacao e priorizacao do parametro Top
    $topLimit = 0
    if ($Top -gt 0) {
        $topLimit = $Top
    }
    elseif ($Top20) {
        $topLimit = 20
    }
    elseif ($Top10) {
        $topLimit = 10
    }

    # Top forca ordenacao por tamanho
    if ($topLimit -gt 0 -and [string]::IsNullOrEmpty($Sort)) {
        $Sort = "Size"
    }

    # Cache local por execucao para evitar recalcular o mesmo diretorio
    # em modos que medem pastas raiz e pastas recursivas.
    # Escopo local: o cache nasce e morre dentro de cada chamada de Get-FolderSize.
    $folderSizeCache = @{}

    function Measure-DirBytes([string]$dir) {
        try {
            $bytes = (Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction Stop |
                     Measure-Object Length -Sum).Sum
            if ($bytes -eq $null) { return 0 }
            return [long]$bytes
        } catch {
            return 0
        }
    }

    function Measure-DirBytesCached([string]$dir) {
        if ([string]::IsNullOrWhiteSpace($dir)) { return 0L }

        $cacheKey = $dir.ToLowerInvariant()
        if ($folderSizeCache.ContainsKey($cacheKey)) {
            return [long]$folderSizeCache[$cacheKey]
        }

        $bytes = Measure-DirBytes $dir
        $folderSizeCache[$cacheKey] = [long]$bytes
        return [long]$bytes
    }

    # -----------------------
    # BLOCO RESUME
    # -----------------------
    if ($Resume) {
        $totalBytes = 0L
        $totalFiles = 0
        $totalDirs  = 0
        $ignoredItems = 0
        $scanErrors = @()

        $items = Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable scanErrors

        if ($scanErrors) {
            $ignoredItems = $scanErrors.Count
        }

        foreach ($i in $items) {
            if ($i.Attributes -match "ReparsePoint") { continue }
            if ($i.PSIsContainer) {
                $totalDirs++
            } else {
                $totalFiles++
                if ($i.Length) { $totalBytes += [long]$i.Length }
            }
        }

        Write-Host ""
        Write-Host "----------------------------------------"
        Write-Host ("TOTAL: {0} | ARQUIVOS: {1} | PASTAS: {2}" -f (Format-Size $totalBytes), $totalFiles, $totalDirs)

        if ($ignoredItems -gt 0) {
            Write-Host ""
            Write-Host ("Aviso: {0} itens não puderam ser lidos." -f $ignoredItems)
        }

        return
    }

    # ============================
    # TOTAL ACCURATE (GUI MODE)
    # ============================
    if ($TotalAccurate) {

        if ($NoBytes) {
            Write-Host "Mode   Tamanho   UN     Tipo                 Nome"
            Write-Host "-----  --------  ------ -------------------- ----------------------------------------"
        }
        else {
            Write-Host "Mode   Tamanho   UN     Bytes        Tipo                 Nome"
            Write-Host "-----  --------  ------ -----------  -------------------- ----------------------------------------"
        }

        Write-Host ""

        $items = @()
        try {
            $items = Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
        } catch { $items = @() }

        $results = @()

        foreach ($i in $items) {
            # ignora junction/reparse
            if ($i.Attributes -match "ReparsePoint") { continue }

            if ($i.PSIsContainer) {
                $mode  = "d-----"
                $bytes = 0
                $tipo  = "Pasta"
            }
            else {
                $mode  = "-a----"
                $bytes = $i.Length
                $tipo  = if ($i.Extension) { $i.Extension.TrimStart(".") } else { "Arquivo" }
            }

            $nome = $i.FullName.Replace($Path, "").TrimStart("\")
            $results += [PSCustomObject]@{ Mode=$mode; Size=[long]$bytes; Name=$nome; Type=$tipo }
        }

        if ($Sort -eq "Size") { $results = $results | Sort-Object Size -Descending }
        elseif ($Sort -eq "Name") { $results = $results | Sort-Object Name }

        # APLICAR LIMITACAO TOP (blindado)
        if ($topLimit -gt 0 -and @($results).Count -gt $topLimit) {
            $results = $results | Select-Object -First $topLimit
        }

        foreach ($r in $results) {
            $formatted = Format-Size $r.Size
            $split = Split-Size $formatted
            if ($NoBytes) {
                Print-Row $r.Mode $split.Number $split.Unit "" $r.Type $r.Name -NoBytes
            } else {
                Print-Row $r.Mode $split.Number $split.Unit $r.Size $r.Type $r.Name
            }
        }

        # TOTAL:
        # - Sem Top: soma real (arquivos) igual Explorer
        # - Com Top: soma apenas dos itens listados (coerente com a mensagem)
        $sum = 0L
        if ($topLimit -gt 0) {
            $sumObj = @($results | Where-Object { $_.Mode -eq "-a----" }) | Measure-Object Size -Sum
            if ($sumObj -and ($null -ne $sumObj.Sum)) { $sum = [long]$sumObj.Sum } else { $sum = 0L }
        }
        else {
            try {
                $sumObj = Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction Stop |
                          Measure-Object Length -Sum
                if ($sumObj -and ($null -ne $sumObj.Sum)) {
                    $sum = [long]$sumObj.Sum
                }
            } catch { $sum = 0L }
        }

        Write-Host ""
        Write-Host "----------------------------------------"
        if ($topLimit -gt 0) {
            Write-Host ("TOTAL (TOP {0} MAIORES): {1}" -f $topLimit, (Format-Size $sum))
        }
        else {
            Write-Host ("TOTAL: " + (Format-Size $sum))
        }
        return
    }

    # ============================
    # MODO -ALL (somente pastas, raiz + recursivas)
    # ============================
    if ($All) {

        if ($NoBytes) {
            Write-Host "Mode   Tamanho   UN     Tipo                 Nome"
            Write-Host "-----  --------  ------ -------------------- ----------------------------------------"
        }
        else {
            Write-Host "Mode   Tamanho   UN     Bytes        Tipo                 Nome"
            Write-Host "-----  --------  ------ -----------  -------------------- ----------------------------------------"
        }

        Write-Host ""

        # Pastas raiz (sem junctions)
        $rootDirs = @()
        try {
            $rootDirs = Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue |
                       Where-Object { -not ($_.Attributes -match "ReparsePoint") }
        } catch { $rootDirs = @() }

        $rootResults = foreach ($d in $rootDirs) {
            $bytes = Measure-DirBytesCached $d.FullName
            [PSCustomObject]@{ Mode="d-----"; Size=$bytes; Name=$d.Name; Type="Pasta" }
        }
        $rootResults = @($rootResults)

        # Pastas recursivas (sem duplicar raiz)
        $recDirs = @()
        try {
            $recDirs = Get-ChildItem -LiteralPath $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue |
                      Where-Object {
                          -not ($_.Attributes -match "ReparsePoint") -and
                          ($rootDirs.FullName -notcontains $_.FullName)
                      }
        } catch { $recDirs = @() }

        $recResults = foreach ($d in $recDirs) {
            $bytes = Measure-DirBytesCached $d.FullName
            $nome = $d.FullName.Replace($Path, "").TrimStart("\")
            [PSCustomObject]@{ Mode="d-----"; Size=$bytes; Name=$nome; Type="Pasta" }
        }
        $recResults = @($recResults)

        # Ordenacao
        if ($Sort -eq "Size") {
            $rootResults = $rootResults | Sort-Object Size -Descending
            $recResults  = $recResults  | Sort-Object Size -Descending
        } elseif ($Sort -eq "Name") {
            $rootResults = $rootResults | Sort-Object Name
            $recResults  = $recResults  | Sort-Object Name
        }

        # APLICAR LIMITACAO TOP (somente em rootResults)
        if ($topLimit -gt 0 -and @($rootResults).Count -gt $topLimit) {
            $rootResults = $rootResults | Select-Object -First $topLimit
        }

        Write-Host "PASTAS DO PRIMEIRO NIVEL"
        foreach ($r in $rootResults) {
            $formatted = Format-Size $r.Size
            $split = Split-Size $formatted
            if ($NoBytes) {
                Print-Row $r.Mode $split.Number $split.Unit "" $r.Type $r.Name -NoBytes
            } else {
                Print-Row $r.Mode $split.Number $split.Unit $r.Size $r.Type $r.Name
            }
        }

        Write-Host ""
        Write-Host "----------------------------------------"
        Write-Host "PASTAS RECURSIVAS"

        # APLICAR LIMITACAO TOP (em recResults)
        if ($topLimit -gt 0 -and @($recResults).Count -gt $topLimit) {
            $recResults = $recResults | Select-Object -First $topLimit
        }

        foreach ($r in $recResults) {
            $formatted = Format-Size $r.Size
            $split = Split-Size $formatted
            if ($NoBytes) {
                Print-Row $r.Mode $split.Number $split.Unit "" $r.Type $r.Name -NoBytes
            } else {
                Print-Row $r.Mode $split.Number $split.Unit $r.Size $r.Type $r.Name
            }
        }

        # Calcular TOTAL (soma apenas rootResults) - blindado
        $sum = 0L
        if (@($rootResults).Count -gt 0) {
            $sumObj = $rootResults | Measure-Object Size -Sum
            if ($sumObj -and ($null -ne $sumObj.Sum)) {
                $sum = [long]$sumObj.Sum
            }
        }

        Write-Host ""
        Write-Host "----------------------------------------"
        if ($topLimit -gt 0) {
            Write-Host ("TOTAL (TOP {0} MAIORES DO PRIMEIRO NIVEL): {1}" -f $topLimit, (Format-Size $sum))
        }
        else {
            Write-Host ("TOTAL: " + (Format-Size $sum))
        }
        return
    }

    # ============================
    # MODO -RECURSE (somente arquivos recursivos)
    # ============================
    if ($Recurse) {

        if ($NoBytes) {
            Write-Host "Mode   Tamanho   UN     Tipo                 Nome"
            Write-Host "-----  --------  ------ -------------------- ----------------------------------------"
        }
        else {
            Write-Host "Mode   Tamanho   UN     Bytes        Tipo                 Nome"
            Write-Host "-----  --------  ------ -----------  -------------------- ----------------------------------------"
        }

        Write-Host ""

        $files = @()
        try { $files = Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue } catch { $files = @() }

        $results = foreach ($f in $files) {
            if ($f.Attributes -match "ReparsePoint") { continue }
            $nome = $f.FullName.Replace($Path, "").TrimStart("\")
            $tipo = if ($f.Extension) { $f.Extension.TrimStart(".") } else { "Arquivo" }
            [PSCustomObject]@{ Mode="-a----"; Size=[long]$f.Length; Name=$nome; Type=$tipo }
        }
        $results = @($results)

        if ($Sort -eq "Size") { $results = $results | Sort-Object Size -Descending }
        elseif ($Sort -eq "Name") { $results = $results | Sort-Object Name }

        # APLICAR LIMITACAO TOP - blindado
        if ($topLimit -gt 0 -and @($results).Count -gt $topLimit) {
            $results = $results | Select-Object -First $topLimit
        }

        foreach ($r in $results) {
            $formatted = Format-Size $r.Size
            $split = Split-Size $formatted
            if ($NoBytes) {
                Print-Row $r.Mode $split.Number $split.Unit "" $r.Type $r.Name -NoBytes
            } else {
                Print-Row $r.Mode $split.Number $split.Unit $r.Size $r.Type $r.Name
            }
        }

        # Calcular TOTAL - blindado
        $sum = 0L
        if (@($results).Count -gt 0) {
            $sumObj = $results | Measure-Object Size -Sum
            if ($sumObj -and ($null -ne $sumObj.Sum)) {
                $sum = [long]$sumObj.Sum
            }
        }

        Write-Host ""
        Write-Host "----------------------------------------"
        if ($topLimit -gt 0) {
            Write-Host ("TOTAL (TOP {0} MAIORES): {1}" -f $topLimit, (Format-Size $sum))
        }
        else {
            Write-Host ("TOTAL: " + (Format-Size $sum))
        }
        return
    }

    # ============================
    # MODO -FULL (pastas primeiro + arquivos depois)
    # TOTAL = soma dos arquivos
    # ============================
    if ($Full) {

        if ($NoBytes) {
            Write-Host "Mode   Tamanho   UN     Tipo                 Nome"
            Write-Host "-----  --------  ------ -------------------- ----------------------------------------"
        }
        else {
            Write-Host "Mode   Tamanho   UN     Bytes        Tipo                 Nome"
            Write-Host "-----  --------  ------ -----------  -------------------- ----------------------------------------"
        }

        Write-Host ""

        # Pastas (primeiro) - recursivo, ignorando junctions
        $dirs = @()
        try {
            $dirs = Get-ChildItem -LiteralPath $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue |
                   Where-Object { -not ($_.Attributes -match "ReparsePoint") }
        } catch { $dirs = @() }

        $dirResults = foreach ($d in $dirs) {
            $bytes = Measure-DirBytesCached $d.FullName
            $nome = $d.FullName.Replace($Path, "").TrimStart("\")
            [PSCustomObject]@{ Mode="d-----"; Size=$bytes; Name=$nome; Type="Pasta" }
        }
        $dirResults = @($dirResults)

        # Arquivos (depois)
        $files = @()
        try { $files = Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue } catch { $files = @() }

        $fileResults = foreach ($f in $files) {
            $nome = $f.FullName.Replace($Path, "").TrimStart("\")
            $tipo = if ($f.Extension) { $f.Extension.TrimStart(".") } else { "Arquivo" }
            [PSCustomObject]@{ Mode="-a----"; Size=[long]$f.Length; Name=$nome; Type=$tipo }
        }
        $fileResults = @($fileResults)

        # Ordenacao (pastas primeiro SEMPRE)
        if ($Sort -eq "Size") {
            $dirResults  = $dirResults  | Sort-Object Size -Descending
            $fileResults = $fileResults | Sort-Object Size -Descending
        } elseif ($Sort -eq "Name") {
            $dirResults  = $dirResults  | Sort-Object Name
            $fileResults = $fileResults | Sort-Object Name
        }

        # APLICAR LIMITACAO TOP (dividido entre pastas e arquivos) - blindado
        if ($topLimit -gt 0) {
            $halfLimit = [math]::Ceiling($topLimit / 2)
            if (@($dirResults).Count -gt $halfLimit) {
                $dirResults = $dirResults | Select-Object -First $halfLimit
            }
            if (@($fileResults).Count -gt $halfLimit) {
                $fileResults = $fileResults | Select-Object -First $halfLimit
            }
        }

        foreach ($r in $dirResults) {
            $formatted = Format-Size $r.Size
            $split = Split-Size $formatted
            if ($NoBytes) {
                Print-Row $r.Mode $split.Number $split.Unit "" $r.Type $r.Name -NoBytes
            } else {
                Print-Row $r.Mode $split.Number $split.Unit $r.Size $r.Type $r.Name
            }
        }

        foreach ($r in $fileResults) {
            $formatted = Format-Size $r.Size
            $split = Split-Size $formatted
            if ($NoBytes) {
                Print-Row $r.Mode $split.Number $split.Unit "" $r.Type $r.Name -NoBytes
            } else {
                Print-Row $r.Mode $split.Number $split.Unit $r.Size $r.Type $r.Name
            }
        }

        # Calcular TOTAL (soma dos arquivos) - blindado
        $sum = 0L
        if (@($fileResults).Count -gt 0) {
            $sumObj = $fileResults | Measure-Object Size -Sum
            if ($sumObj -and ($null -ne $sumObj.Sum)) {
                $sum = [long]$sumObj.Sum
            }
        }

        Write-Host ""
        Write-Host "----------------------------------------"
        if ($topLimit -gt 0) {
            Write-Host ("TOTAL (TOP {0} MAIORES - ARQUIVOS): {1}" -f $topLimit, (Format-Size $sum))
        }
        else {
            Write-Host ("TOTAL: " + (Format-Size $sum))
        }
        return
    }

    # ============================
    # MODO PADRAO (somente pastas do diretorio atual)
    # TOTAL = soma das pastas listadas (1o nivel)
    # ============================

    if ($NoBytes) {
        Write-Host "Mode   Tamanho   UN     Tipo                 Nome"
        Write-Host "-----  --------  ------ -------------------- ----------------------------------------"
    }
    else {
        Write-Host "Mode   Tamanho   UN     Bytes        Tipo                 Nome"
        Write-Host "-----  --------  ------ -----------  -------------------- ----------------------------------------"
    }

    Write-Host ""

    $dirs = @()
    try {
        $dirs = Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue |
               Where-Object { -not ($_.Attributes -match "ReparsePoint") }
    } catch { $dirs = @() }

    $results = foreach ($d in $dirs) {
        $bytes = Measure-DirBytesCached $d.FullName
        [PSCustomObject]@{ Mode="d-----"; Size=$bytes; Name=$d.Name; Type="Pasta" }
    }
    $results = @($results)

    if ($Sort -eq "Size") { $results = $results | Sort-Object Size -Descending }
    elseif ($Sort -eq "Name") { $results = $results | Sort-Object Name }

    # APLICAR LIMITACAO TOP - blindado
    if ($topLimit -gt 0 -and @($results).Count -gt $topLimit) {
        $results = $results | Select-Object -First $topLimit
    }

    foreach ($r in $results) {
        $formatted = Format-Size $r.Size
        $split = Split-Size $formatted
        if ($NoBytes) {
            Print-Row $r.Mode $split.Number $split.Unit "" $r.Type $r.Name -NoBytes
        }
        else {
            Print-Row $r.Mode $split.Number $split.Unit $r.Size $r.Type $r.Name
        }
    }

    # Calcular TOTAL - blindado
    $sum = 0L
    if (@($results).Count -gt 0) {
        $sumObj = $results | Measure-Object Size -Sum
        if ($sumObj -and ($null -ne $sumObj.Sum)) {
            $sum = [long]$sumObj.Sum
        }
    }

    Write-Host ""
    Write-Host "----------------------------------------"
    if ($topLimit -gt 0) {
        Write-Host ("TOTAL (TOP {0} MAIORES): {1}" -f $topLimit, (Format-Size $sum))
    }
    else {
        Write-Host ("TOTAL: " + (Format-Size $sum))
    }
}

Export-ModuleMember -Function Get-FolderSize, Format-Size, Get-DriveSize, Get-StorageOverview