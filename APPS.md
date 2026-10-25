# App Notes

## Firefox Language Discovery

`Get-MozillaFirefox` returns all published installer languages by default. It reads
each active channel's `SHA256SUMS` file to discover localized EXE/MSI installers,
rather than resolving a download URL for every language and installer combination.
Inactive channels and unpublished installer combinations are excluded.
The `Sha256` property contains the published checksum for each EXE/MSI installer.
For MSIX packages it is `$null`, because they are not listed in `SHA256SUMS`.

Use `Get-MozillaFirefox -Language en-US` or
`Get-MozillaFirefox -Language en-US,de` to filter localized installers.
Multilingual MSIX packages are always returned once per channel and architecture
with `Language` set to `Multi`, including when a language filter is specified.

Run the Firefox regression tests with Pester 5:

```powershell
Invoke-Pester -Path ./_scripts/MozillaFirefox.Tests.ps1
```

## Thunderbird Language Discovery

`Get-MozillaThunderbird` returns all published languages by default using each
active channel's `SHA256SUMS` file to discover Windows EXE/MSI installers.
Use `Get-MozillaThunderbird -Language en-US` or
`Get-MozillaThunderbird -Language en-US,de` to filter localized installers.
Inactive channels and unpublished installer combinations are excluded.

Each EXE/MSI result includes its published `Sha256` checksum. Multilingual MSIX
packages are returned once per channel and architecture with `Language` set to
`Multi` and `Sha256` set to `$null`, including when a language filter is specified.
MSIX download resolution uses the channel's exact version.

Run the Thunderbird regression tests with Pester 5:

```powershell
Invoke-Pester -Path ./_scripts/MozillaThunderbird.Tests.ps1
```
