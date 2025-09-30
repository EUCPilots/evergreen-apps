@{
    CustomRulePath      = @(".rules/LowercaseKeywords.psm1")
    IncludeDefaultRules = $true
    Severity            = @("Error", "Warning")
    IncludeRules        = @(
        "Measure*"
    )
}
