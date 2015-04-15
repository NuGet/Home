param (
    [ValidateSet("debug", "release")][string]$Configuration="release",    
    [switch]$Clean
)

# Build a project k project.
# - projectDirectory is the root directory of the project
# - outputDirectory is the directory where the generated nupkg files are copied to
function ProjectKBuild([string]$projectDirectory, [string]$outputDirectory) 
{
    Write-Host "======== Building in $ProjectDirectory ======"

    # build the project
    & "$projectDirectory\build.cmd"
    Write-Output "last exit code $lastexitcode"
    if ($lastexitcode -ne 0) 
    {		
    	throw "Build failed"
    }

    # copy the generated nupkgs
    $artifactDirectory = Join-Path $projectDirectory "artifacts\build"
    Copy-Item (Join-Path $artifactDirectory "*.nupkg") $outputDirectory -Verbose:$true
}

# remove NuGet.* packages from the specified directory
function RemovePackages([string]$packagesDirectory)
{
    if (Test-Path "$packagesDirectory") 
    { 
        rm -r -force "$packagesDirectory\NuGet.*" 
    }
}

function BuildNuGetPackageManagement()
{
	cd "$GitRoot\NuGet.PackageManagement"
	$env:NUGET_PUSH_TARGET = $packagesDirectory
	& "$GitRoot\NuGet.PackageManagement\pack.ps1" -Configuration $Configuration -PushTarget $packagesDirectory -Version $Version -NoLock
	$result = $lastexitcode
	cd $GitRoot

	if ($result -ne 0) 
	{		
	  	throw "Build failed"
	}
	
	Copy-Item "$GitRoot\NuGet.PackageManagement\nupkgs\*.nupkg" "$packagesDirectory"
}

# version number of non-k projects
$Version="3.0.0-beta"

# set environment used by k
$env:Configuration=$Configuration
$env:DNX_BUILD_VERSION="beta"

# Create the packages directory
$GitRoot = Get-Location
$packagesDirectory = "$GitRoot\nupkgs"
if (!(Test-Path $packagesDirectory))
{
	mkdir $packagesDirectory
}

if ($Clean)
{
    rm "$packagesDirectory\*.nupkg"
    
    RemovePackages "$GitRoot\NuGet.Versioning\packages"
    RemovePackages "$GitRoot\NuGet.Configuration\packages"
    RemovePackages "$GitRoot\NuGet.Packaging\packages"
    RemovePackages "$GitRoot\NuGet.Protocol\packages"
    RemovePackages "$GitRoot\NuGet.PackageManagement\packages"
    RemovePackages "$GitRoot\NuGet.CommandLine\packages"
    RemovePackages "$GitRoot\NuGet.VisualStudioExtension\packages"
}

# build k-based solutions
ProjectKBuild "$GitRoot\NuGet.Versioning" "$GitRoot\nupkgs"
ProjectKBuild "$GitRoot\NuGet.Configuration" "$GitRoot\nupkgs"
ProjectKBuild "$GitRoot\NuGet.Packaging" "$GitRoot\nupkgs"
ProjectKBuild "$GitRoot\NuGet.Protocol" "$GitRoot\nupkgs"

# now build NuGet.PackageManagement
BuildNuGetPackageManagement