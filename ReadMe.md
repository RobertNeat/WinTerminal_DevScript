# Setup-Terminal

  <img src="resources/ps_fluent_design_384.svg" alt="PowerShell Fluent Design icon" width="128" height="128">

Setup-Terminal is a PowerShell_5-based setup project for applying a consistent Windows Terminal configuration on a developer workstation.

The project currently focuses on detecting common developer runtimes and creating Windows Terminal profiles for them. It is designed to grow over time with more profiles, prompt configuration, and terminal setup helpers.

This script only reaches web in order to download:

- Oh My Posh
- winfeth

The key consideration is that the script does not download any other assets or configuration files from the web. All other configuration is done locally.

## What It Configures

- Windows Terminal `settings.json`
- Developer profiles for detected tools:
  - Git Bash
  - Python
  - Node.js
  - Java (only detection)
- Profile icons for supported developer tools
- Selected Windows Terminal dynamic profile sources
- Terminal color schemes
- Additional Windows Terminal profile settings
- Oh My Posh setup and winfetch for PowerShell
- Basic terminal behavior settings, such as tab width mode and web search URL

Planned additions include more profiles and setup steps, including Winfetch configuration.

<p align="center">
  <img src="resources/shells_image.png" alt="Multiple shells outcome screenshot">
</p>

## Requirements

- Windows
- Windows Terminal
- PowerShell
- Git, Python, and Node.js, Java installed if you want matching profiles to be generated
  - best to install using: official installer, Python version manager, Node version manager, Java JDK Adoptium Temurin

- Oh My Posh if you want prompt customization to work

## Usage

Run the setup script from the repository root:

```powershell
.\Setup-Terminal.ps1
```

The script detects installed developer tools, updates Windows Terminal profiles, applies additional settings, and saves the configuration back to the active Windows Terminal `settings.json`.

## Side effects

The script will download files from the web (but each time it will ask for permission with reference to the source URL).
Additionally the script modifies the files in system locations as follows:

echo "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\icons"
echo "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\marcduiker.omp.json"
echo "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
echo "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
echo "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

## Project Structure

```text
Setup-Terminal.ps1              Main setup script
modules/                        PowerShell modules used by the setup script
resources/                      Shared icons and other project assets
```

## Asset Attribution

This project includes `resources/ps_fluent_design_384.svg` for README branding.

The icon is not my original asset. It comes from the official PowerShell repository:

[PowerShell Fluent Design icon](https://github.com/PowerShell/PowerShell/blob/master/assets/ps_fluent_design_384.svg)

The upstream PowerShell repository is licensed under the MIT License.

## License

Project license is not defined yet.
