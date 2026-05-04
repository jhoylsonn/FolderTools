# FolderTools

##  Descrição
O FolderTools é um módulo PowerShell projetado para análise avançada de armazenamento no Windows, permitindo calcular tamanhos de diretórios, arquivos e perfis de usuário com alta precisão e desempenho.

O projeto foi desenvolvido com foco em uso via terminal, automação e cenários administrativos (infraestrutura/DevOps).

---

##  Instalação


Links Para Powershell para Download Remoto:

### 🔹1-Instalação automática (recomendado)

iwr -useb https://raw.githubusercontent.com/jhoylsonn/FolderTools/main/install.ps1 | iex

### 🔹2- Comando Link Curto:

iwr -useb https://tinyurl.com/Foldertools | iex



---

### 🔹 Instalação manual
git clone https://github.com/jhoylsonn/FolderTools.git
cd FolderTools
.\install.ps1

---

## ⚙️ Uso

###  Análise básica
Get-FolderSize C:\Users

---

###  Modo resumido (rápido)
Get-FolderSize C:\Users -Resume

Saída:
----------------------------------------
TOTAL: 1,43 GB | ARQUIVOS: 4987 | PASTAS: 320

---

###  Análise completa
Get-FolderSize C:\Users -All

---

###  Listagem detalhada
Get-FolderSize C:\Users -Full

---

###  Cálculo preciso (estilo Explorer)
Get-FolderSize C:\Users -TotalAccurate

---

##  Parâmetros principais

- -Resume → Exibe resumo rápido
- -All → Análise completa
- -Full → Lista arquivos
- -TotalAccurate → Cálculo detalhado equivalente ao Explorer

---

##  Estrutura do Projeto

FolderTools/
│
├── FolderTools.psm1
├── FolderTools.psd1
├── install.ps1
└── README.md

---

## ️ Versionamento

- 6.1 → versão estável atual
- 5.9.x → versões anteriores

---

##  Release

git add .
git commit -m "release: FolderTools 6.x"
git push origin main

git tag v6.x
git push origin v6.x

---

##  Roadmap

- Execução paralela (runspaces)
- Output estruturado (objetos PowerShell)
- Exportação (CSV / JSON)
- Melhorias de performance

---

##  Licença
Definir (recomendado: MIT)

---

##  Autor
Joilson Michell
