# netcore.nvim

This plugin is in alpha development.

A comprehensive Neovim plugin for managing .NET solutions, projects, tests, and NuGet packages directly from your editor.
Designed for .NET Core 8.0 and above, it provides an integrated experience for .NET developers using Neovim.

## Features

- **Solution Management**: Create, build, rebuild, clean, restore, and test solutions; create projects from templates, add existing projects from disk, and remove projects
- **Project Management**: Build (instant Debug/Release or a custom build wizard), rebuild, publish, test, and manage project-to-project references
- **Current-File Commands**: Build, open NuGet, or manage references for whichever project the file you are editing belongs to
- **Test Runner**: Interactive test runner with visual pass/fail indicators and detailed results
- **NuGet Package Manager**: Browse, install, update, and uninstall NuGet packages with a fuzzy-finder interface — per project or across the whole solution, including version consolidation
- **Command History**: Track and re-run previous commands

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "rf0ster/netcore.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("netcore").setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wabbittwacks/packer.nvim)

```lua
use {
  "rf0ster/netcore.nvim",
  requires = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("netcore").setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'nvim-telescope/telescope.nvim'
Plug 'rf0ster/netcore.nvim'

lua << EOF
require("netcore").setup()
EOF
```

## Setup

Add the following to your Neovim configuration:

```lua
require("netcore").setup()
```

All options are optional:

```lua
require("netcore").setup({
  nuget = {
    ui = {
      width = 0.8,        -- fraction of the screen width for the nuget manager
      height = 0.8,       -- fraction of the screen height for the nuget manager
      border = "rounded", -- window border style
      style = "minimal",  -- window style
    },
    cache = {
      use_cache = true,   -- cache NuGet API responses for the session
    },
  },
})
```

## Usage

The plugin provides the following commands:

- `:Dotnet solution` - Open the solution manager
- `:Dotnet projects` - Open the project manager
- `:Dotnet nuget` - Open the solution-level NuGet manager
- `:Dotnet proj_build` - Open the build menu for the current file's project
- `:Dotnet proj_build debug|release` - Instantly build the current file's project with that configuration
- `:Dotnet proj_nuget` - Open the NuGet manager for the current file's project
- `:Dotnet proj_ref` - Manage references for the current file's project
- `:Dotnet tests` - Open the interactive test runner
- `:Dotnet history` - View command history
- `:Dotnet last_cmd` - Re-run the last command

The `proj_*` commands identify the project by walking up the directory tree
from the file in the current buffer until a `.csproj`/`.fsproj`/`.vbproj` is
found — no solution required.

## Keymaps

You can create custom keymaps for the Dotnet commands. Here are some recommended mappings:

```lua
-- Add these to your init.lua or wherever you configure keymaps
vim.keymap.set("n", "<leader>ds", "<cmd>Dotnet solution<CR>", { desc = "Dotnet solution manager" })
vim.keymap.set("n", "<leader>dp", "<cmd>Dotnet projects<CR>", { desc = "Dotnet project manager" })
vim.keymap.set("n", "<leader>dn", "<cmd>Dotnet nuget<CR>", { desc = "Dotnet solution nuget manager" })
vim.keymap.set("n", "<leader>dt", "<cmd>Dotnet tests<CR>", { desc = "Dotnet test runner" })
vim.keymap.set("n", "<leader>dh", "<cmd>Dotnet history<CR>", { desc = "Dotnet command history" })
vim.keymap.set("n", "<leader>dl", "<cmd>Dotnet last_cmd<CR>", { desc = "Dotnet run last command" })

-- Current-file project commands
vim.keymap.set("n", "<leader>pb", "<cmd>Dotnet proj_build<CR>", { desc = "Build menu for current project" })
vim.keymap.set("n", "<leader>pd", "<cmd>Dotnet proj_build debug<CR>", { desc = "Build current project (Debug)" })
vim.keymap.set("n", "<leader>pr", "<cmd>Dotnet proj_build release<CR>", { desc = "Build current project (Release)" })
vim.keymap.set("n", "<leader>pn", "<cmd>Dotnet proj_nuget<CR>", { desc = "NuGet for current project" })
vim.keymap.set("n", "<leader>pf", "<cmd>Dotnet proj_ref<CR>", { desc = "References for current project" })
```

## Requirements

- Neovim >= 0.11.0
- .NET SDK installed and available in PATH for netcore +8.0
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (used for the pickers)
- `curl` on your PATH (used for NuGet API requests)

## Solution Manager

`:Dotnet solution` opens a menu of solution commands. If no solution file
(`.sln` or `.slnx`) exists in the current directory, you are prompted to
create one. Each option shows its hotkey inline; `<CR>` runs the highlighted
option.

| Key | Action |
| --- | ------ |
| `b` | Build (Debug/Release) |
| `B` | Rebuild (clean + build) |
| `c` | Clean |
| `r` | Restore |
| `t` | Run tests |
| `g` | Open the solution NuGet manager |
| `n` | New project from a template (console, classlib, mstest, xunit, nunit, web, webapi, mvc, blazor, worker) |
| `a` | Add an existing project found on disk |
| `d` | Remove a project from the solution |

## Project Manager

`:Dotnet projects` lists the solution's projects.

| Key | Action |
| --- | ------ |
| `m` / `<CR>` | Open the project submenu |
| `n` | Open the project NuGet manager |
| `b` | Open the build menu |
| `c` | Clean |
| `r` | Restore |
| `a` | Add a project reference |
| `p` | Toggle relative/absolute paths |

The project submenu offers: Open, Build, Rebuild, Publish, Test, References,
NuGet, Clean, Restore, and Delete.

### Build Menu

Reached with `b`, from the submenu, or via `:Dotnet proj_build`:

- **Debug** / **Release** - build immediately with that configuration
- **Custom** - a step-by-step wizard: configuration → runtime → verbosity →
  build flags (checkbox list: `--no-restore`, `--no-dependencies`,
  `--no-incremental`, `--force`, `--self-contained`) → optional target
  framework and output directory → a final editable command line that runs
  on `<CR>`

In checkbox lists: `<Space>`/`x` toggles an item, `a` toggles all,
`<CR>` confirms, `<Esc>`/`q` cancels.

### References

Reached from the submenu, `a` in the projects list, or `:Dotnet proj_ref`.
Lists the project's project-to-project references:

| Key | Action |
| --- | ------ |
| `a` | Add a reference to another solution project |
| `d` | Remove the selected reference |

## Test Runner

The test runner provides an interactive interface with three panes:

- **Left pane**: Solution/project/test hierarchy
- **Right pane**: Detailed test results (output, stack trace, timing)
- **Bottom pane**: Raw test output

### Test Runner Keymaps

When in the test runner window:
- `r` - Run the test/project/solution under cursor
- `<CR>` (Enter) - Fold/unfold the project under the cursor (`<Tab>` and `za` do the same)
- `zM` / `zR` - Fold/unfold every project
- `R` - Reload tests

## NuGet Package Manager

### Project-level

Opened with `n` in the project manager, from the submenu, or via
`:Dotnet proj_nuget`. Three tabs, switched with the capital-letter keys;
`P` toggles prerelease packages in search results; `<Esc>` closes the manager.

- **Browse** (`B`) - Search and browse NuGet packages
  - `<leader>i` - Install the selected package
  - `<leader>v` - Toggle the version list for the selected package
- **Installed** (`I`) - View installed packages
  - `<leader>u` - Uninstall the selected package (the list refreshes automatically)
- **Updates** (`U`) - Check for package updates
  - `<leader>u` - Update the selected package to its latest version
  - `<leader>a` - Update all outdated packages

### Solution-level

`:Dotnet nuget` (or `g` in the solution manager) manages packages across
every project in the solution with the same UI. Four tabs:

- **Browse** (`B`) - Search packages
  - `<leader>i` - Install into a chosen set of projects (checkbox modal)
  - `<leader>v` - Toggle the version list
- **Installed** (`I`) - Aggregated packages with per-project versions shown in the detail pane
  - `<leader>u` - Uninstall from a chosen set of projects
- **Updates** (`U`) - Outdated packages across the solution
  - `<leader>u` - Update the selected package in every project that contains it
  - `<leader>a` - Update everything
- **Consolidate** (`C`) - Packages installed with mismatched versions across projects
  - `<leader>c` - Pick one version to apply to every project containing the package

## Command History

`:Dotnet history` opens a picker of previously run commands; `<CR>` re-runs
the selected command. `:Dotnet last_cmd` re-runs the most recent one.
