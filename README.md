# scaffold-js-cli

*Zero-friction JavaScript project initialization tool*

![PowerShell](https://img.shields.io/badge/PowerShell-Core-blue?logo=powershell) ![GitHub API](https://img.shields.io/badge/GitHub-API-black?logo=github) ![Node.js](https://img.shields.io/badge/Node.js-Compatible-green?logo=nodedotjs)

---

## About

Starting a new JavaScript project has a lot of repetitive overhead — cloning a template, clearing git history, figuring out which package manager the template uses, and opening the editor. `New-JSProject.ps1` compresses all of that into a single command.

It connects to the GitHub API via the `gh` CLI to fetch your personal template repositories, presents an interactive selection menu, clones your choice, resets the git history for a clean slate, detects and runs the correct package manager, and opens the project in VS Code — all without leaving the terminal.

---

## Features

- **GitHub integration** — fetches your personal JS/TS templates dynamically via the GitHub API; no hardcoded lists to maintain
- **Interactive CLI menu** — browse and select from your available templates with input validation
- **Smart dependency installation** — detects `pnpm-lock.yaml`, `yarn.lock`, `bun.lockb`, or `package-lock.json` and runs the correct install command automatically
- **Git history reset** — removes the template's `.git` folder and initializes a fresh repo with a clean initial commit
- **Auto-launch** — opens the scaffolded project in VS Code when setup is complete

---

## Prerequisites

The following tools must be installed and available in your PATH:

- [`gh` (GitHub CLI)](https://cli.github.com/) — authenticated via `gh auth login`
- `git`
- A JS package manager — `npm`, `pnpm`, `yarn`, or `bun`
- VS Code (`code` command) — optional, for auto-launch

> **Note:** Templates are fetched from your authenticated GitHub account. Your template repos must be tagged with the `template` topic on GitHub to be detected. See [GitHub's topic documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics) for setup instructions.

---

## Usage

**Interactive mode** — launches a numbered menu to browse and select a template:
```powershell
.\New-JSProject.ps1 -ProjectName "my-dashboard"
```

**Fast mode** — skips the menu if you already know the template name:
```powershell
.\New-JSProject.ps1 -ProjectName "next-app" -TemplateName "nextjs-starter"
```

**Custom parent directory** — scaffolds the project in a specific location:
```powershell
.\New-JSProject.ps1 -ProjectName "my-dashboard" -ParentPath "C:\Dev\Projects"
```

---

## Architecture

**Strategy Pattern — dependency installer**

Rather than a chain of `if/else` blocks, the installer uses an ordered hashtable that maps lockfile names to install commands. The script walks the list in priority order and runs the first match it finds:

```powershell
$InstallStrategies = [ordered]@{
    "pnpm-lock.yaml"    = { pnpm install }
    "yarn.lock"         = { yarn install }
    "bun.lockb"         = { bun install }
    "package-lock.json" = { npm install }
    "package.json"      = { npm install }
}
```

This makes adding support for a new package manager a one-line change, and keeps the detection logic easy to read and reason about.

**GitHub API integration**

Templates are fetched using the `gh` CLI with a `--topic template` filter, then narrowed further by matching repository topics against JS ecosystem keywords (`js`, `typescript`, `react`, `nextjs`, etc.). This means the template list stays in sync with your GitHub account automatically — no manual updates needed.

---

## License

[MIT](LICENSE)