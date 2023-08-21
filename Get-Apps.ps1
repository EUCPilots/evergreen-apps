$params = @{
    Uri             = "https://api.github.com/repos/EUCPilots/evergreen-apps/contents/Manifests?ref=main"
    UseBasicParsing = $true
    Headers         = @{
        "Accept"               = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
}
irm @params


mkdir "$Env:HOME/.evergreen"
