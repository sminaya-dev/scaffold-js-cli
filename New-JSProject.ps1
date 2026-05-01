<#
.SYNOPSIS
    New-JSProject - JavaScript/TypeScript Project Scaffolder

.DESCRIPTION
    Streamlines the creation of new JS/TS projects by pulling from GitHub templates.
    It automatically detects the preferred package manager (pnpm, yarn, npm) based on lockfiles
    and handles the full git initialization process.

    NOTE: Templates are fetched from the currently authenticated GitHub user's repositories
    (via 'gh auth'). To use this script, you must be logged in with the GitHub CLI
    ('gh auth login') and have repos tagged with the 'template' topic in your account.
    See: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics

.PARAMETER ProjectName
    The name of the new folder to create.

.PARAMETER TemplateName
    (Optional) The exact name of the GitHub repository to clone.

.PARAMETER ParentPath
    The parent directory where the project will be created. Defaults to current location.

.EXAMPLE
    New-JSProject -ProjectName "my-dashboard"
    
.EXAMPLE
    New-JSProject -ProjectName "next-app" -TemplateName "nextjs-starter"
#>

function New-JSProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ProjectName,

        [Parameter(Position = 1)]
        [string]$TemplateName,

        # Default to current location ($PWD) if not specified, simpler for users
        [Parameter(Position = 2)]
        [string]$ParentPath = $PWD
    )

    # -------------------------------------------------------------------------
    # 1. SETUP & PATH RESOLUTION
    # -------------------------------------------------------------------------
    
    # Priority list for dependency installation
    $InstallStrategies = [ordered]@{
        "pnpm-lock.yaml"    = { Write-Host "   Detected pnpm."; pnpm install }
        "yarn.lock"         = { Write-Host "   Detected yarn."; yarn install }
        "bun.lockb"         = { Write-Host "   Detected bun."; bun install }
        "package-lock.json" = { Write-Host "   Detected npm."; npm install }
        "package.json"      = { Write-Host "   Defaulting to npm."; npm install } 
    }

    # Safe Path Construction (Fixes the Resolve-Path crash)
    if (-not (Test-Path $ParentPath)) {
        try {
            New-Item -ItemType Directory -Path $ParentPath -Force | Out-Null
        }
        catch {
            Write-Error "❌ Could not create parent path '$ParentPath'"
            return
        }
    }
    $projectPath = Join-Path $ParentPath $ProjectName

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "❌ GitHub CLI (gh) is required. Run 'winget install GitHub.cli'"
        return
    }

    # -------------------------------------------------------------------------
    # 2. TEMPLATE SELECTION
    # -------------------------------------------------------------------------
    Write-Host "🔍 Fetching templates..." -ForegroundColor Cyan
    
    try {
        # Fetch, Parse JSON, then Filter
        $repos = gh repo list --topic template --json "name,sshUrl,repositoryTopics,description" --limit 50 |
        ConvertFrom-Json | 
        Where-Object { 
            # Flexible matching for JS ecosystem terms
            $_.repositoryTopics.name -match 'js|javascript|typescript|node|react|nextjs|vue' 
        }
    }
    catch {
        Write-Error "Failed to fetch templates. Ensure you are logged in (gh auth login)."
        return
    }

    if (-not $repos) { 
        Write-Warning "No templates found with JS/TS topics."
        return 
    }

    # Select Template
    $selectedRepo = $null
    
    if ($TemplateName) { 
        $selectedRepo = $repos | Where-Object { $_.name -eq $TemplateName }
        if (-not $selectedRepo) { Write-Warning "Template '$TemplateName' not found." }
    }

    if (-not $selectedRepo) {
        Write-Host "`nSelect a template:" -ForegroundColor Green
        for ($i = 0; $i -lt $repos.Count; $i++) {
            Write-Host "$($i+1). " -NoNewline -ForegroundColor Yellow
            Write-Host "$($repos[$i].name)" -ForegroundColor Cyan -NoNewline
            if ($repos[$i].description) { Write-Host " - $($repos[$i].description)" -ForegroundColor Gray } else { Write-Host "" }
        }

        # Input Validation Loop (Prevents crashes on bad input)
        do {
            $choice = Read-Host "`nEnter number (1-$($repos.Count))"
            if ($choice -match '^\d+$' -and $choice -ge 1 -and $choice -le $repos.Count) {
                $selectedRepo = $repos[$choice - 1]
                break
            }
            Write-Warning "Invalid selection."
        } while ($true)
    }

    # -------------------------------------------------------------------------
    # 3. EXECUTION
    # -------------------------------------------------------------------------
    Write-Host "`n🚀 Scaffolding at: $projectPath" -ForegroundColor Cyan

    # Git clone handles folder creation, but we ensure parent exists above.
    git clone $selectedRepo.sshUrl $projectPath
    if ($LASTEXITCODE -ne 0) { return }

    Set-Location $projectPath

    # Detach from template history
    if (Test-Path .git) {
        Remove-Item -Recurse -Force .git
        git init | Out-Null
        git add . | Out-Null
        git commit -m "Initial scaffold from $($selectedRepo.name)" | Out-Null
        Write-Host "✂️  Git history reset." -ForegroundColor DarkGray
    }

    # -------------------------------------------------------------------------
    # 4. INSTALLATION
    # -------------------------------------------------------------------------
    Write-Host "📦 Installing dependencies..." -ForegroundColor Cyan
    
    $installed = $false
    foreach ($file in $InstallStrategies.Keys) {
        if (Test-Path $file) {
            & $InstallStrategies[$file]
            $installed = $true
            break 
        }
    }

    if (-not $installed) {
        Write-Warning "No package manager lockfile found. Skipping install."
    }

    # -------------------------------------------------------------------------
    # 5. FINAL LAUNCH
    # -------------------------------------------------------------------------
    Write-Host "`n✅ Project ready!" -ForegroundColor Green
    
    if (Get-Command code -ErrorAction SilentlyContinue) {
        code .
    }
    else {
        Write-Warning "VS Code (code) not found in PATH."
    }
}
