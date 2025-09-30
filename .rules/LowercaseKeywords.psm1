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
        $nodes = $ScriptAst.FindAll({
            param($node)
            # Only return true for relevant command keywords or variable constants
            if ($node -is [System.Management.Automation.Language.CommandElementAst]) {
                $actual = $node.Extent.Text
                $lower = $actual.ToLower()
                if ($keywords -contains $lower) {
                    return $true
                }
            } elseif ($node -is [System.Management.Automation.Language.VariableExpressionAst]) {
                $actual = $node.Extent.Text
                $lower = $actual.ToLower()
                if ($constants -contains $lower) {
                    return $true
                }
            }
            return $false
        }, $true)

        foreach ($node in $nodes) {
            if ($node -is [System.Management.Automation.Language.CommandElementAst]) {
                $actual = $node.Extent.Text
                $lower = $actual.ToLower()
                if ($keywords -contains $lower) {
                    if ($actual -cne $lower) {
                        [DiagnosticRecord]@{
                            Message  = "Keyword '$actual' should be lowercase ('$lower')."
                            Extent   = $node.Extent
                            RuleName = 'LowercaseKeywords'
                            Severity = 'Warning'
                        }
                    }
                }
            } elseif ($node -is [System.Management.Automation.Language.VariableExpressionAst]) {
                $actual = $node.Extent.Text
                $lower = $actual.ToLower()
                if ($constants -contains $lower) {
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
}
