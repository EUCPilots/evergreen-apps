# LowercaseKeywords.psm1
using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic

function Measure-LowercaseKeywords {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.Ast] $ScriptAst,

        [Parameter(Mandatory)]
        [string] $ScriptPath
    )

    process {
        # Define what we care about
        $keywords = @('function', 'foreach', 'if')
        $constants = @('$true', '$false', '$null')
        $targets = $keywords + $constants

        # Find all CommandElements and VariableExpressions in the AST
        $nodes = @()
        $ScriptAst.FindAll({
            param($node)
            if ($node -is [System.Management.Automation.Language.CommandElementAst]) {
                $actual = $node.Extent.Text
                $lower = $actual.ToLower()
                if ($keywords -contains $lower) {
                    $script:nodes += [PSCustomObject]@{
                        Node   = $node
                        Actual = $actual
                        Lower  = $lower
                        Type   = 'Keyword'
                    }
                }
            } elseif ($node -is [System.Management.Automation.Language.VariableExpressionAst]) {
                $actual = $node.Extent.Text
                $lower = $actual.ToLower()
                if ($constants -contains $lower) {
                    $script:nodes += [PSCustomObject]@{
                        Node   = $node
                        Actual = $actual
                        Lower  = $lower
                        Type   = 'Constant'
                    }
                }
            }
            return $false
        }, $true) | Out-Null

        foreach ($item in $nodes) {
            $node = $item.Node
            $actual = $item.Actual
            $lower = $item.Lower
            if ($item.Type -eq 'Keyword') {
                if ($actual -cne $lower) {
                    [DiagnosticRecord]@{
                        Message  = "Keyword '$actual' should be lowercase ('$lower')."
                        Extent   = $node.Extent
                        RuleName = 'LowercaseKeywords'
                        Severity = 'Warning'
                    }
                }
            } elseif ($item.Type -eq 'Constant') {
                if ($actual -cne $lower) {
                    [DiagnosticRecord]@{
                        Message  = "Constant '$actual' should be lowercase ('$lower')."
                        Extent   = $node.Extent
                        RuleName = 'LowercaseKeywords'
                        Severity = 'Warning'
                    }
                }
            }
        }
    }
}
