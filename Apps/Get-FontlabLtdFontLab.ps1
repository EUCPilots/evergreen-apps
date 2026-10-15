function Get-FontlabLtdFontLab {
    <#
        .SYNOPSIS
            Returns the latest FontLab version number and download.

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

    # Get the latest update information from the manifest
    $Update = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri
    if ($null -ne $Update) {

        try {
            # Create an HTTP client that does not automatically follow redirects
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $handler.AllowAutoRedirect = $false
            $client = [System.Net.Http.HttpClient]::new($handler)
        }
        catch {
            throw "$($MyInvocation.MyCommand): Failed to create HTTP client: $_"
        }
        
        # Get the final redirected URL without following the redirect automatically
        # Existing redirection functions were not working
        $Url = try {
            $client.DefaultRequestHeaders.UserAgent.ParseAdd(
                $script:resourceStrings.UserAgent.Base
            )
            $client.DefaultRequestHeaders.Accept.ParseAdd(
                $res.Get.Download.RequestHeaders
            )
            $client.DefaultRequestHeaders.AcceptLanguage.ParseAdd('en-US,en;q=0.9')
            $client.DefaultRequestHeaders.Referrer = [uri]$res.Get.Download.Referrer

            $response = $client.GetAsync(
                $Update.enclosure.url
            ).GetAwaiter().GetResult()

            try {
                if ([int]$response.StatusCode -ne 302 -or
                    $null -eq $response.Headers.Location) {
                    throw "$($MyInvocation.MyCommand): Expected a redirect; received HTTP $([int]$response.StatusCode)."
                }
                $response.Headers.Location.AbsoluteUri
            }
            finally {
                $response.Dispose()
            }
        }
        finally {
            $client.Dispose()
        }

        foreach ($Item in $Update.Enclosure) {
            [PSCustomObject] @{
                Version      = $Item.version
                Architecture = Get-Architecture -String $Url
                Type         = Get-FileType -File $Url
                URI          = $Url
            }
        }
    }
}
