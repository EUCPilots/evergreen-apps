# 🌲 Evergreen Apps Repository

Welcome to the **Evergreen Apps** repo! This is repo hosts application functions and manifests for the Evergreen module.

## 🚀 What is This Repo?

This repository hosts:

- **Application Functions**: The logic that powers Evergreen's supported application features.
- **Manifests**: Configuration files that describe how apps detection works.

Check out [Evergreen Documentation](https://eucpilots.com/evergreen-docs) for detailed guides.

## ℹ How to Use

If you want to contribute to this project with fixes or new applications, set up your local environment as follows:

1. Install the [Evergreen](https://www.powershellgallery.com/packages/Evergreen/) module, or clode the [evergreen-module](https://github.com/EUCPilots/evergreen-module) repository.
2. Clone this repository.
3. Configure the Evergreen environment for local development by creating the `EVERGREEN_APPS_PATH` environment variable, pointing to the location of the local repository: [Set a custom cache location](https://eucpilots.com/evergreen-docs/updateapps#set-a-custom-cache-location). For example:

```powershell
$env:EVERGREEN_APPS_PATH="C:\projects\evergreen-apps"
```

or

```powershell
$env:EVERGREEN_APPS_PATH="/Users/aaron/projects/_EUCPilots/evergreen-apps"
```

4. Import the Evergreen module, for example:

```powershell
Import-Module -Name Evergreen -Force
```

or

```powershell
Import-Module -Name "/Users/aaron/projects/_EUCPilots/evergreen-module/Evergreen" -Force
```

5. Implement your changes in a new branch and create a pull request.
