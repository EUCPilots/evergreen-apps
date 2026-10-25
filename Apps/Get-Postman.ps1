function Get-Postman {
    <#
        .SYNOPSIS
            Get the current version and download URIs for Postman.

        .NOTES
            Author: Andrew Cooper
            Twitter: @adotcoop
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    # Query the Postman update API
    foreach ($item in $res.Get.Update.Uri.GetEnumerator()) {
        $params = @{
            Uri         = $res.Get.Update.Uri[$item.Key]
            ContentType = $res.Get.Update.ContentType
        }
        $Content = Invoke-EvergreenRestMethod @params
        if ($null -ne $Content) {

            # Work out latest version
            $LatestVersion = $Content.changelog | `
                Where-Object { $_.name -match '^\d+(?:\.\d+){1,3}$' } | `
                Sort-Object -Property @{ Expression = { [System.Version]$_.name }; Descending = $true } | `
                Select-Object -First 1

            # Construct the output; Return the custom object to the pipeline
            $PSObject = [PSCustomObject] @{
                Version      = $LatestVersion.name
                Size         = $LatestVersion.assets.size
                Sha1         = $LatestVersion.assets.hash
                Date         = ConvertTo-DateTime -DateTime ($LatestVersion.createdAt) -Pattern $res.Get.Update.DatePattern
                Architecture = Get-Architecture -String $item.Name
                Filename     = $LatestVersion.assets.name
                URI          = $LatestVersion.assets.url
            }
            Write-Output -InputObject $PSObject
        }
    }
}
