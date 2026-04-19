<#
    FolderTools - Versão 5.9.1
    Autor: Joilson Michell
    Descrição: Ferramentas avançadas para análise de pastas, perfis e armazenamento.
#>

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

    $Formatted = $Formatted.Trim() -replace "\s+", " "

    if ($Formatted -match "^([\d\.,]+)\s+(\w+)$") {
        return @{
            Number = $matches[1]
            Unit   = $matches[2]
        }
    }

    return @{
        Number = $Formatted
        Unit   = "bytes"
    }
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

# ============================
# PARTE 2 - INÍCIO
# ============================

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
            if (Test-Path $path -ErrorAction Stop) {
                return (Get-ChildItem $path -Recurse -File -Force -ErrorAction SilentlyContinue |
                        Measure-Object Length -Sum).Sum
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

    if ($Help) {
        Write-Host "==========================="
        Write-Host "   FOLDERTOOLS 5.9.1 - HELP"
        Write-Host "==========================="
        Write-Host ""
        Write-Host "Get-FolderSize                       - Lista pastas do diretorio atual"
        Write-Host "Get-FolderSize -All                  - Lista somente pastas (raiz + recursivas)"
        Write-Host "                                       Total = soma das pastas do primeiro nivel"
        Write-Host "Get-FolderSize -Recurse              - Lista todos os arquivos recursivamente"
        Write-Host "Get-FolderSize -Full                 - Lista pastas + arquivos (pastas primeiro)"
        Write-Host "                                       Total = soma dos arquivos (sem duplicação)"
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
        Write-Host "Get-FolderSize C:\ -Sort Size"
        Write-Host "Get-FolderSize -Full -Sort Size -NoBytes"
        Write-Host "Get-FolderSize -TotalAccurate C:\Users\Joilson\Documents"
        Write-Host "Get-FolderSize -All C:\Users\Joilson\Documents -Sort Size"
        Write-Host ""
        return
    }

    if ($Overview) { Get-StorageOverview $Path; return }
    if ($Drivers) { Get-DriveSize; return }

    $Path = (Resolve-Path $Path).Path

    #
    #  TOTAL ACCURATE (GUI MODE)
    #
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

        $items = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue

        $results = @()

        foreach ($i in $items) {

            if ($i.PSIsContainer) {
                if ($i.Attributes -match "ReparsePoint") { continue }

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
            $results += [PSCustomObject]@{
                Mode = $mode
                Size = $bytes
                Name = $nome
                Type = $tipo
            }
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

        $sum = (Get-ChildItem $Path -Recurse -File -Force | Measure-Object Length -Sum).Sum
        if ($sum -eq $null) { $sum = 0 }

        Write-Host ""
        Write-Host "----------------------------------------"
        Write-Host ("TOTAL: " + (Format-Size $sum))
        return
    }

# ============================
# PARTE 2 - FIM
# ============================

# ============================
# PARTE 3 - INÍCIO
# ============================

    #
    #  MODO -ALL (somente pastas, raiz + recursivas)
    #
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
        $rootDirs = Get-ChildItem -Path $Path -Directory -Force |
                    Where-Object { -not ($_.Attributes -match "ReparsePoint") }

        $rootResults = foreach ($d in $rootDirs) {
            $bytes = (Get-ChildItem $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                      Measure-Object Length -Sum).Sum
            if ($bytes -eq $null) { $bytes = 0 }

            [PSCustomObject]@{
                Mode = "d-----"
                Size = $bytes
                Name = $d.Name
                Type = "Pasta"
            }
        }

        # Pastas recursivas (sem duplicar raiz)
        $recDirs = Get-ChildItem -Path $Path -Directory -Recurse -Force |
                   Where-Object {
                       -not ($_.Attributes -match "ReparsePoint") -and
                       ($rootDirs.FullName -notcontains $_.FullName)
                   }

        $recResults = foreach ($d in $recDirs) {
            $bytes = (Get-ChildItem $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                      Measure-Object Length -Sum).Sum
            if ($bytes -eq $null) { $bytes = 0 }

            $nome = $d.FullName.Replace($Path, "").TrimStart("\")
            [PSCustomObject]@{
                Mode = "d-----"
                Size = $bytes
                Name = $nome
                Type = "Pasta"
            }
        }

        # Ordenação
        if ($Sort -eq "Size") {
            $rootResults = $rootResults | Sort-Object Size -Descending
            $recResults  = $recResults  | Sort-Object Size -Descending
        }
        elseif ($Sort -eq "Name") {
            $rootResults = $rootResults | Sort-Object Name
            $recResults  = $recResults  | Sort-Object Name
        }

        Write-Host "PASTAS DO PRIMEIRO NIVEL"
        foreach ($r in $rootResults) {
            $formatted = Format-Size $r.Size
            $split = Split-Size $formatted

            if ($NoBytes) {
                Print-Row $r.Mode $split.Number $split.Unit "" $r.Type $r.Name -NoBytes
            }
            else {
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
            }
            else {
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

    #
    #  MODO -FULL (PASTAS PRIMEIRO + TOTAL = SOMA DOS ARQUIVOS)
    #
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

        # PASTAS (primeiro)
        $dirs = Get-ChildItem -Path $Path -Directory -Recurse -Force |
                Where-Object { -not ($_.Attributes -match "ReparsePoint") }

        $dirResults = foreach ($d in $dirs) {
            $bytes = (Get-ChildItem $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                      Measure-Object Length -Sum).Sum
            if ($bytes -eq $null) { $bytes = 0 }

            $nome = $d.FullName.Replace($Path, "").TrimStart("\")
            [PSCustomObject]@{
                Mode = "d-----"
                Size = $bytes
                Name = $nome
                Type = "Pasta"
            }
        }

        # ARQUIVOS (depois)
        $files = Get-ChildItem -Path $Path -Recurse -File -Force

        $fileResults = foreach ($f in $files) {
            $bytes = $f.Length
            if ($bytes -eq $null) { $bytes = 0 }

            $nome = $f.FullName.Replace($Path, "").TrimStart("\")
            $tipo = if ($f.Extension) { $f.Extension.TrimStart(".") } else { "Arquivo" }

            [PSCustomObject]@{
                Mode = "-a----"
                Size = $bytes
                Name = $nome
                Type = $tipo
            }
        }

        # Ordenação (pastas primeiro SEMPRE)
        if ($Sort -eq "Size") {
            $dirResults  = $dirResults  | Sort-Object Size -Descending
            $fileResults = $fileResults | Sort-Object Size -Descending
        }
        elseif ($Sort -eq "Name") {
            $dirResults  = $dirResults  | Sort-Object Name
            $fileResults = $fileResults | Sort-Object Name
        }

        # Exibir pastas
        foreach ($r in $dirResults) {
            $formatted = Format-Size $r.Size
            $split = Split-Size $formatted

            if ($NoBytes) {
                Print-Row $r.Mode $split.Number $split.Unit "" $r.Type $r.Name -NoBytes
            }
            else {
                Print-Row $r.Mode $split.Number $split.Unit $r.Size $r.Type $r.Name
            }
        }

        # Exibir arquivos
        foreach ($r in $fileResults) {
            $formatted = Format-Size $r.Size
            $split = Split-Size $formatted

            if ($NoBytes) {
                Print-Row $r.Mode $split.Number $split.Unit "" $r.Type $r.Name -NoBytes
            }
            else {
                Print-Row $r.Mode $split.Number $split.Unit $r.Size $r.Type $r.Name
            }
        }

        # TOTAL = SOMA DOS ARQUIVOS (NÃO DAS PASTAS)
        $sum = ($fileResults | Measure-Object Size -Sum).Sum
        if ($sum -eq $null) { $sum = 0 }

        Write-Host ""
        Write-Host "----------------------------------------"
        Write-Host ("TOTAL: " + (Format-Size $sum))
        return
    }

    #
    #  MODO PADRÃO (somente pastas do diretório atual)
    #
    if ($NoBytes) {
        Write-Host "Mode   Tamanho   UN     Tipo                 Nome"
        Write-Host "-----  --------  ------ -------------------- ----------------------------------------"
    }
    else {
        Write-Host "Mode   Tamanho   UN     Bytes        Tipo                 Nome"
        Write-Host "-----  --------  ------ -----------  -------------------- ----------------------------------------"
    }

    Write-Host ""

    $dirs = Get-ChildItem -Path $Path -Directory -Force |
            Where-Object { -not ($_.Attributes -match "ReparsePoint") }

    $results = foreach ($d in $dirs) {
        $bytes = (Get-ChildItem $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                  Measure-Object Length -Sum).Sum
        if ($bytes -eq $null) { $bytes = 0 }

        [PSCustomObject]@{
            Mode = "d-----"
            Size = $bytes
            Name = $d.Name
            Type = "Pasta"
        }
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

# ============================
# PARTE 3 - FIM
# ============================
