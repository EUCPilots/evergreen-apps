function Get-voidtoolsEverything {
    <#
        .SYNOPSIS
            Returns the available voidtools Everything versions.

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

    # Pass the repo releases API URL and return a formatted object
    $Response = Invoke-EvergreenRestMethod -Uri $res.Get.Update.Uri

    # Build the output object
    if ($null -ne $Response) {

        # Construct the version number from the response, skipping the first line
        try {
            $Version = ($Response.Split("`n")[1, 2, 3, 4] | ConvertFrom-StringData).Values -join "."
        }
        catch {
            $Version = "Unknown"
        }

        # Return an object for each architecture
        foreach ($item in $res.Get.Download.Uri.GetEnumerator()) {
            $PSObject = [PSCustomObject] @{
                Version      = $Version
                Architecture = $item.Name
                URI          = $res.Get.Download.Uri[$item.Key]
            }
            Write-Output -InputObject $PSObject
        }
    }
}
