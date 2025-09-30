function Get-OperaAirBrowser {
    <#
        .SYNOPSIS
            Returns the available Opera Air Browser versions and download URIs.

        .NOTES
            Author: Aaron Parker

    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    $Output = Get-OperaApp -res $res
    Write-Output -InputObject $Output
}
