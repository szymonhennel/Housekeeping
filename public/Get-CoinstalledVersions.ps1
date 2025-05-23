function Get-CoinstalledVersions {
    param(
        [string[]]$Ignore = @(   # List of package names to ignore
            'Security Intelligence Update for Microsoft Defender Antivirus'
        ),

        [Parameter(Mandatory=$false)]
        [switch]$ResolveProvider
    )
    # Fetch installed packages using Get-Package
    $packages = Get-Package

    # Normalize package names by removing version numbers and architecture specifics
    function Format-PackageName($name) {
        $name -replace ' \d+(\.\d+)*', ''
    }

    # Create a hashtable to track package names and their versions
    $normalizedPackages = @{}
    foreach ($package in $packages) {
        $normalizedName = Format-PackageName $package.Name

        # Check if $package.Version is not null before calling ToString()
        if ($null -ne $package.Version) {
            $versionString = $package.Version.ToString()
        } else {
            # Handle the case where Version is null, e.g., by using a placeholder or skipping
            $versionString = "Unknown Version"
        }

        $providerName = $package.ProviderName

        # Check if the normalized package name is in the Ignore list
        # Initialize a flag to indicate if the package should be ignored
        $shouldIgnore = $false
        # Check each ignore list entry with wildcards for a match
        foreach ($ignorePattern in $Ignore) {
            if ($normalizedName -like "*$ignorePattern*") {
                $shouldIgnore = $true
                break # Exit the loop if a match is found
            }
        }
        # Skip this package if it should be ignored
        if ($shouldIgnore) {
            continue
        }

        # Create an entry in the hashtable if it doesn't exist yet
        if (-not $normalizedPackages.ContainsKey($normalizedName)) {
            $normalizedPackages[$normalizedName] = @()
        }
        
        # Add the version string to the hashtable entry
        if ($ResolveProvider) {
            $normalizedPackages[$normalizedName] += $versionString
            
        } else {
            $normalizedPackages[$normalizedName] += [PSCustomObject]@{
                Version = $versionString
                Provider = $providerName
            }
        }
    }

    # Identify normalized names with multiple versions
    $namesWithMultipleVersions = $normalizedPackages.GetEnumerator() |
        Where-Object {
            if ($ResolveProvider) {
                $_.Value.Count -gt 1
            } else {
                (($_.Value).Version | Select-Object -Unique).Count -gt 1
            }
        } | 
        ForEach-Object { $_.Key }

    # Filter raw packages based on normalized names with multiple versions
    $filteredPackages = $packages | Where-Object {
        $normalizedName = Format-PackageName $_.Name
        $namesWithMultipleVersions -contains $normalizedName
    }

    # Sort the filtered packages alphabetically by Name
    $filteredPackages | Sort-Object Name
}