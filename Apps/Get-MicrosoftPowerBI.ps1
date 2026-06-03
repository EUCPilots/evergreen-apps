function Get-MicrosoftPowerBI {
    <#
        .SYNOPSIS

    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    foreach ($Url in $res.Get.Download.Uri) {
        [PSCustomObject]@{
            Version      = $res.Get.Download.Version
            Date         = ConvertTo-DateTime -DateTime $res.Get.Download.Date -Pattern $res.Get.Download.DatePattern
            Architecture = Get-Architecture -String $Url
            Type         = Get-FileType -File $Url
            Filename     = (Split-Path -Path $Url -Leaf).Replace('%20', ' ')
            URI          = $Url -replace ' ', '%20'
        }
    }
}
