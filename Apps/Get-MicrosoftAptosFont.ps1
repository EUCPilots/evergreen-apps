function Get-MicrosoftAptosFont {
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

    [PSCustomObject]@{
        Version      = $res.Get.Download.Version
        Date         = ConvertTo-DateTime -DateTime $res.Get.Download.Date -Pattern $res.Get.Download.DatePattern
        Type         = Get-FileType -File $res.Get.Download.Uri
        Filename     = (Split-Path -Path $res.Get.Download.Uri -Leaf).Replace('%20', ' ')
        URI          = $res.Get.Download.Uri -replace ' ', '%20'
    }
}
