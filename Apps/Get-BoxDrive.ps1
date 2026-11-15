function Get-BoxDrive {
    <#
        .SYNOPSIS
            Get the current version and download URIs for the supported releases of Box Drive.
    #>
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    # Query the update feed for the current version and download URIs of Box Drive
    $params = @{
        Uri       = $res.Get.Update.Uri
        # UserAgent = $res.Get.Update.UserAgent
    }
    $UpdateFeed = Invoke-EvergreenRestMethod @params

    # Get the list of properties for the specified update property (e.g., "win")
    $Properties = $UpdateFeed.$($res.Get.Update.Property) | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name"

    # Iterate over each property and construct the output object
    foreach ($Property in $Properties) {
        [PSCustomObject] @{
            Version = $UpdateFeed.$($res.Get.Update.Property).$Property.version
            Channel = $Property
            Type    = Get-FileType -File $UpdateFeed.$($res.Get.Update.Property).$Property.'download-url'
            URI     = $UpdateFeed.$($res.Get.Update.Property).$Property.'download-url'
        }
    }
}
