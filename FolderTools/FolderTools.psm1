<#
    FolderTools - Versao 5.9.2
    Autor: Joilson Michell
    Descricao: Ferramentas avancadas para analise de pastas, perfis e armazenamento.

    Objetivo desta revisao:
    - Restaurar o comportamento e layout da 5.9.1 (Print-Row/Write-Host), incluindo:
      * -All com separacao "PASTAS DO PRIMEIRO NIVEL" e "PASTAS RECURSIVAS"
      * -TotalAccurate (GUI mode) listando TUDO (pastas + arquivos) com total igual Explorer (somente arquivos)
      * -Full (pastas primeiro + arquivos depois) e TOTAL = soma dos arquivos
      * -Help com texto customizado (igual 5.9.1)
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
    $drives = Get-PSDrive -PSProvider FileSystem
    Write-Host "Drive  Total        Usado        Livre        %Usado  Tipo"
    Write-Host "-----  -----------  -----------  -----------  ------  ------"
    foreach ($d in $drives) {
        $total = $d.Used + $d.Free
        $pct = if ($total -gt 0) { [math]::Round(($d.Used / $total) * 100) } else { 0 }
        $tipo = "Desconhecido"
        try { $tipo = (New-Object System.IO.DriveInfo($d.Root)).DriveType } catch {}
        Write-Host ($d.Name.PadRight(5)) (Format-Size $total).PadRight(12) (Format-Size $d.Used).PadRight(12) (Format-Size $d.Free).PadRight(12) (($pct.ToString() + "%").PadRight(7)) $tipo
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
    Write-Host "Disco: $root\\"
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
        [string]$Sort
    )

    # HELP customizado (como 5.9.1)
    if ($Help) {
        Write-Host "==========================="
        Write-Host "   FOLDERTOOLS 5.9.2 - HELP"
        Write-Host "==========================="
        Write-Host ""
        Write-Host "Get-FolderSize                       - Lista pastas do diretorio atual"
        Write-Host "Get-FolderSize -All                  - Lista somente pastas (raiz + recursivas)"
        Write-Host "                                       Total = soma das pastas do primeiro nivel"
        Write-Host "Get-FolderSize -Recurse              - Lista todos os arquivos recursivamente"
        Write-Host "Get-FolderSize -Full                 - Lista pastas + arquivos (pastas primeiro)"
        Write-Host "                                       Total = soma dos arquivos (sem duplicacao)"
        Write-Host "Get-FolderSize -TotalAccurate        - Modo GUI (pastas + arquivos, total exato)"
        Write-Host "Get-FolderSize -Sort Size            - Ordena por tamanho"
        Write-Host "Get-FolderSize -Sort Name            - Ordena por nome"
        Write-Host "Get-FolderSize -NoBytes              - Oculta a coluna Bytes"
        Write-Host "Get-FolderSize -Drivers              - Mostra informacoes dos discos"
        Write-Host "Get-FolderSize -Overview             - Resumo estilo Windows 10/11"
        Write-Host "Get-DriveSize                        - Mostra informacoes dos discos"
        Write-Host "Get-StorageOverview                  - Resumo direto do armazenamento"
        Write-Host ""
        Write-Host "Exemplos:"
        Write-Host ""
        Write-Host "Get-FolderSize C:\Users\Joilson\Documents"
        Write-Host "Get-FolderSize C:\\ -Sort Size"
        Write-Host "Get-FolderSize -Full -Sort Size -NoBytes"
        Write-Host "Get-FolderSize -TotalAccurate C:\Users\Joilson\Documents"
        Write-Host "Get-FolderSize -All C:\Users\Joilson\Documents -Sort Size"
        Write-Host ""
        return
    }

    if ($Overview) { Get-StorageOverview $Path; return }
    if ($Drivers) { Get-DriveSize; return }

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolved) { Write-Host "Caminho invalido: $Path"; return }
    $Path = $resolved.Path

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

        foreach ($r in $results) {
            $formatted = Format-Size $r.Size
            $split = Split-Size $formatted
            if ($NoBytes) {
                Print-Row $r.Mode $split.Number $split.Unit "" $r.Type $r.Name -NoBytes
            } else {
                Print-Row $r.Mode $split.Number $split.Unit $r.Size $r.Type $r.Name
            }
        }

        # TOTAL = soma apenas dos arquivos reais
        $sum = 0L
        try {
            $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction Stop |
                    Measure-Object Length -Sum).Sum
        } catch { $sum = 0 }
        if ($sum -eq $null) { $sum = 0 }

        Write-Host ""
        Write-Host "----------------------------------------"
        Write-Host ("TOTAL: " + (Format-Size $sum))
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
            $bytes = Measure-DirBytes $d.FullName
            [PSCustomObject]@{ Mode="d-----"; Size=$bytes; Name=$d.Name; Type="Pasta" }
        }

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
            $bytes = Measure-DirBytes $d.FullName
            $nome = $d.FullName.Replace($Path, "").TrimStart("\")
            [PSCustomObject]@{ Mode="d-----"; Size=$bytes; Name=$nome; Type="Pasta" }
        }

        # Ordenacao
        if ($Sort -eq "Size") {
            $rootResults = $rootResults | Sort-Object Size -Descending
            $recResults  = $recResults  | Sort-Object Size -Descending
        } elseif ($Sort -eq "Name") {
            $rootResults = $rootResults | Sort-Object Name
            $recResults  = $recResults  | Sort-Object Name
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

        foreach ($r in $recResults) {
            $formatted = Format-Size $r.Size
            $split = Split-Size $formatted
            if ($NoBytes) {
                Print-Row $r.Mode $split.Number $split.Unit "" $r.Type $r.Name -NoBytes
            } else {
                Print-Row $r.Mode $split.Number $split.Unit $r.Size $r.Type $r.Name
            }
        }

        $sum = ($rootResults | Measure-Object Size -Sum).Sum
        if ($sum -eq $null) { $sum = 0 }

        Write-Host ""
        Write-Host "----------------------------------------"
        Write-Host ("TOTAL: " + (Format-Size $sum))
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

        if ($Sort -eq "Size") { $results = $results | Sort-Object Size -Descending }
        elseif ($Sort -eq "Name") { $results = $results | Sort-Object Name }

        foreach ($r in $results) {
            $formatted = Format-Size $r.Size
            $split = Split-Size $formatted
            if ($NoBytes) {
                Print-Row $r.Mode $split.Number $split.Unit "" $r.Type $r.Name -NoBytes
            } else {
                Print-Row $r.Mode $split.Number $split.Unit $r.Size $r.Type $r.Name
            }
        }

        $sum = ($results | Measure-Object Size -Sum).Sum
        if ($sum -eq $null) { $sum = 0 }

        Write-Host ""
        Write-Host "----------------------------------------"
        Write-Host ("TOTAL: " + (Format-Size $sum))
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
            $bytes = Measure-DirBytes $d.FullName
            $nome = $d.FullName.Replace($Path, "").TrimStart("\")
            [PSCustomObject]@{ Mode="d-----"; Size=$bytes; Name=$nome; Type="Pasta" }
        }

        # Arquivos (depois)
        $files = @()
        try { $files = Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue } catch { $files = @() }

        $fileResults = foreach ($f in $files) {
            $nome = $f.FullName.Replace($Path, "").TrimStart("\")
            $tipo = if ($f.Extension) { $f.Extension.TrimStart(".") } else { "Arquivo" }
            [PSCustomObject]@{ Mode="-a----"; Size=[long]$f.Length; Name=$nome; Type=$tipo }
        }

        # Ordenacao (pastas primeiro SEMPRE)
        if ($Sort -eq "Size") {
            $dirResults  = $dirResults  | Sort-Object Size -Descending
            $fileResults = $fileResults | Sort-Object Size -Descending
        } elseif ($Sort -eq "Name") {
            $dirResults  = $dirResults  | Sort-Object Name
            $fileResults = $fileResults | Sort-Object Name
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

        $sum = ($fileResults | Measure-Object Size -Sum).Sum
        if ($sum -eq $null) { $sum = 0 }

        Write-Host ""
        Write-Host "----------------------------------------"
        Write-Host ("TOTAL: " + (Format-Size $sum))
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
        $bytes = Measure-DirBytes $d.FullName
        [PSCustomObject]@{ Mode="d-----"; Size=$bytes; Name=$d.Name; Type="Pasta" }
    }

    if ($Sort -eq "Size") { $results = $results | Sort-Object Size -Descending }
    elseif ($Sort -eq "Name") { $results = $results | Sort-Object Name }

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

    $sum = ($results | Measure-Object Size -Sum).Sum
    if ($sum -eq $null) { $sum = 0 }

    Write-Host ""
    Write-Host "----------------------------------------"
    Write-Host ("TOTAL: " + (Format-Size $sum))
}

Export-ModuleMember -Function Get-FolderSize, Format-Size, Get-DriveSize, Get-StorageOverview
