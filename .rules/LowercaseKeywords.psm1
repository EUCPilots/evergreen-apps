# LowercaseKeywords.psm1
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic

function Measure-LowercaseKeywords {
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]$ScriptAst,

        [Parameter(Mandatory = $false)]
        [System.String]$FilePath
    )

    process {
        # Tokenize the script
        $parseErrors = @()
        $tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptAst, [ref]$parseErrors)
        if ($parseErrors) {
            return $null
        }

        # Define what we care about
        $keywords = @('function', 'foreach', 'if', 'else', 'elseif', 'return', 'switch', 'param', 'begin', 'process', 'end', 'in', 'do', 'while', 'until', 'for', 'trap', 'throw', 'catch', 'try', 'finally', 'data', 'dynamicparam')
        $constants = @('$true', '$false', '$null', '$pwd', '$home', '$shellid', '$host', '$error', '$args', '$this', '$input', '$matches', '$nullstring')
        $targets = $keywords + $constants

        foreach ($t in $tokens) {
            $actual = $t.Content
            $lower = $actual.ToLower()

            if ($targets -contains $lower) {
                if ($actual -cne $lower) {
                    [System.String]$correction = 'Update keyword/constant to lowercase.'
                    $params = @{
                        TypeName     = 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent'
                        ArgumentList = $t.StartLine, $t.EndLine, $t.StartColumn, $t.EndColumn, $correction, $FilePath
                    }
                    $correctionExtent = New-Object @params
                    $suggestedCorrections = New-Object -TypeName System.Collections.ObjectModel.Collection[$($params.TypeName)]
                    $suggestedCorrections.Add($correctionExtent) | Out-Null
                    [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                        Message              = "Keyword/constant '$actual' should be lowercase '$lower'."
                        Extent               = $t.Extent
                        RuleName             = 'LowercaseKeywords'
                        Severity             = 'Warning'
                        SuggestedCorrections = $suggestedCorrections
                    }
                }
            }
        }
    }
}

Export-ModuleMember -Function Measure-LowercaseKeywords
