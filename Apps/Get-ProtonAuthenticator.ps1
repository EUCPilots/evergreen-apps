function Get-ProtonAuthenticator {
    <#
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    # Read the update source
    $params = @{
        Uri = $res.Get.Update.Uri
    }
    $Updates = Invoke-EvergreenRestMethod @params

    # Convert the update JSON string
    if ($Updates -is [System.String]) {
        try {
            $Updates = $Updates | ConvertFrom-Json -ErrorAction "Continue"
        }
        catch {
            # Update feed may include duplicate keys in the JSON
            $Updates = $Updates -creplace $res.Get.Update.ReplaceString, "" | ConvertFrom-Json -ErrorAction "Stop"
        }
    }

    # Simplify access to releases
    $Releases = $Updates.Releases

    # Process each category
    foreach ($Category in ($Releases.CategoryName | Select-Object -Unique)) {
        Write-Verbose -Message "$($MyInvocation.MyCommand): Processing category: $Category"

        # Sort for the latest version
        $LatestVersion = $Releases | Where-Object { $_.CategoryName -eq $Category } | `
            Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } -ErrorAction "SilentlyContinue" | `
            Select-Object -First 1
        Write-Verbose -Message "$($MyInvocation.MyCommand): Latest version in category '$Category' is $($LatestVersion.Version)"

        # Construct the output; Return the custom object to the pipeline
        $PSObject = [PSCustomObject] @{
            Version = $LatestVersion.Version
            Date    = ConvertTo-DateTime -DateTime $LatestVersion.ReleaseDate -Pattern $res.Get.Update.DatePattern
            Release = $LatestVersion.CategoryName
            Sha512  = $LatestVersion.File.Sha512CheckSum
            Type    = Get-FileType -File $LatestVersion.File.Url
            URI     = $LatestVersion.File.Url
        }
        Write-Output -InputObject $PSObject
    }
}
