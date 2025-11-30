#Requires -Module @{ ModuleName="Evergreen"; ModuleVersion="2511.2823.0" }
function Get-AzulZulu17 {
    <#
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

    # Return details freom the AzulZulu function
    $Output = Get-AzulZulu -res $res
    Write-Output -InputObject $Output
}
