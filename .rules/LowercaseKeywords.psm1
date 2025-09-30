# LowercaseKeywords.psm1
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic

function Measure-LowercaseKeywords {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $ScriptAst,

        [Parameter(Mandatory)]
        [string] $ScriptPath
    )

    process {
        # Tokenize the script
        $parseErrors = @()
        $tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptAst, [ref]$parseErrors)

        if ($parseErrors) {
            return
        }

        # Define what we care about
        $keywords = @('function', 'foreach', 'if')
        $constants = @('`$true', '`$false', '`$null')
        $targets = $keywords + $constants

        foreach ($t in $tokens) {
            $actual = $t.Content
            $lower = $actual.ToLower()

            if ($targets -contains $lower) {
                if ($actual -cne $lower) {
                    [DiagnosticRecord]@{
                        Message  = "Keyword/constant '$actual' should be lowercase ('$lower')."
                        Extent   = $t.Extent
                        RuleName = 'LowercaseKeywords'
                        Severity = 'Warning'
                    }
                }
            }
        }
    }
}
