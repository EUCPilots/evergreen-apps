function Get-BitviseSSHClient {
    [OutputType([System.Management.Automation.PSObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [System.Management.Automation.PSObject]
        $res = (Get-FunctionResource -AppName ("$($MyInvocation.MyCommand)".Split("-"))[1])
    )

    $Response = Invoke-EvergreenWebRequest -Uri $res.Get.Update.Uri -ReturnObject "All"
    $Response.RawContentStream.Position = 0
    $Reader = [System.IO.BinaryReader]::new($Response.RawContentStream)
    try {
        $LengthBytes = $Reader.ReadBytes(4)
        if ($LengthBytes.Length -ne 4) {
            throw "Invalid Bitvise update response: missing XML length."
        }
        if ([System.BitConverter]::IsLittleEndian) {
            [System.Array]::Reverse($LengthBytes)
        }
        $Length = [System.BitConverter]::ToUInt32($LengthBytes, 0)
        if ($Length -eq 0 -or $Length -gt [int]::MaxValue -or $Length -gt ($Reader.BaseStream.Length - $Reader.BaseStream.Position)) {
            throw "Invalid Bitvise update response: incomplete XML frame."
        }
        $XmlBytes = $Reader.ReadBytes([int]$Length)
        if ($XmlBytes.Length -ne $Length) {
            throw "Invalid Bitvise update response: incomplete XML frame."
        }
        $Encoding = [System.Text.UTF8Encoding]::new($false, $true)
        [xml]$Feed = $Encoding.GetString($XmlBytes)
    }
    finally {
        $Reader.Dispose()
    }

    $Version = $Feed.versions.version
    if ([string]::IsNullOrWhiteSpace($Version.ver) -or [string]::IsNullOrWhiteSpace($Version.installer)) {
        throw "Invalid Bitvise update response: missing version or installer."
    }

    [PSCustomObject]@{
        Version = $Version.ver
        Date    = ConvertTo-DateTime -DateTime $Version.minupax -AutoDetect
        Sha512  = $Version.sha512
        Type    = Get-FileType -File $Version.installer
        URI     = $Version.installer
    }
}
