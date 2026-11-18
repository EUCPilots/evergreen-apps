function Get-Gpg4win {
    <#
        .SYNOPSIS
            Returns the available gpg4win versions.

        .NOTES
            Author: BornToBeRoot
            Twitter: @_BornToBeRoot
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    # Get update details from update feed
    $Response = Invoke-EvergreenWebRequest -Uri $res.Get.Update.Uri -ReturnObject "All"

    # Convert response content to string if it is in byte array format
    if ($Response.Content -is [byte[]]) {
        $Content = [System.Text.Encoding]::UTF8.GetString($Response.Content)
    }
    
    # Parse the response content line by line and update metadata accordingly
    $Metadata = $res.Get.Update.Metadata
    foreach ($line in ($Content -split '\r?\n')) {
        if ($line -match '^\s*(?<key>\S+)\s+(?<value>\S+)\s*$' -and $Metadata.ContainsKey($Matches['key'])) {
            $Metadata[$Matches['key']] = $Matches['value']
        }
    }

    # Ensure all required metadata fields are populated
    $missing = @($Metadata.Keys | Where-Object { $null -eq $Metadata[$_] })
    if ($missing.Count -gt 0) {
        throw "Missing Gpg4win properties in ${res.Get.Update.Uri}: $($missing -join ', ')"
    }

    # Return the final object with all relevant information
    $Object = [PSCustomObject]$Metadata
    [PSCustomObject] @{
        Version      = $Object.gpg4win_ver
        Date         = ConvertTo-DateTime -DateTime $Object.gpg4win_date -AutoDetect
        #Size         = $Object.gpg4win_exe_size
        Sha256       = $Object.gpg4win_exe_sha2
        Architecture = Get-Architecture -String $res.Get.Download.Architecture
        Type         = Get-FileType -File $res.Get.Download.Uri
        URI          = $res.Get.Download.Uri -f $Object.gpg4win_ver
    }
}
