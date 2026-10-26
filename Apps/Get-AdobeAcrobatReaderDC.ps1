function Get-AdobeAcrobatReaderDC {
    <#
        .SYNOPSIS
            Gets the download URLs for Adobe Acrobat Reader DC Continuous track installers.

        .NOTES
            Author: Aaron Parker
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    #region Installer downloads
    Write-Verbose -Message "$($MyInvocation.MyCommand): Enumerating $($res.Get.Update.Languages.Count) languages."
    foreach ($language in $res.Get.Update.Languages.GetEnumerator()) {

        # Get the full name of the language
        $LanguageFullName = $($res.Get.Update.Languages[$language.Key])

        # Get the installer display names for the specified language
        Write-Verbose -Message "$($MyInvocation.MyCommand): Searching updates for language: $LanguageFullName."
        $UpdateContent = Invoke-EvergreenRestMethod $($res.Get.Update.Uri -replace "#Language", $language.Name)
        Write-Verbose -Message "$($MyInvocation.MyCommand): Found $($UpdateContent.products.reader.count) items for language $LanguageFullName."

        if ($null -ne $UpdateContent) {

            # Sort and get unique versions of the products for the specified language
            if (($UpdateContent.products.reader.version | Select-Object -Unique).Count -gt 1) {

                Write-Verbose -Message "$($MyInvocation.MyCommand): Found multiple versions for language: $LanguageFullName."
                $Version = $UpdateContent.products.reader.version | Select-Object -Unique | Sort-Object -Property { [System.Version]$_ } -Descending | Select-Object -First 1
                $UpdateContent.products.reader = @(
                    $UpdateContent.products.reader | Where-Object { $_.version -eq $Version }
                )
            }

            # Get the download URLs for each product for the specified language
            foreach ($Product in $UpdateContent.products.reader) {

                try {
                    # Search for downloads for each display name returned for the language
                    Write-Verbose -Message "$($MyInvocation.MyCommand): Searching downloads for language: $LanguageFullName."
                    $DownloadContent = Invoke-EvergreenRestMethod $($res.Get.Download.Uri -replace "#DisplayName", $Product.displayName -replace "#ShortLanguage", $language.Name -replace " ", "%20")

                    # Build the output object
                    if ($null -ne $DownloadContent) {
                        $PSObject = [PSCustomObject] @{
                            Version      = $Product.version
                            Language     = $LanguageFullName
                            Size         = [System.Int32]$Product.fileSize
                            Architecture = Get-Architecture -String $(Split-Path -Path $DownloadContent.downloadURL -Leaf)
                            Type         = Get-FileType -File $(Split-Path -Path $DownloadContent.downloadURL -Leaf)
                            URI          = $DownloadContent.downloadURL
                        }
                        Write-Output -InputObject $PSObject
                    }
                }
                catch {
                    Write-Warning -Message "$($MyInvocation.MyCommand): Failed to get download for $($Product.displayName)"
                }
            }
        }
    }
    #endregion
}
