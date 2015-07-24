param (
    [ValidateSet("debug", "release")][string]$Configuration="debug",

    [switch]$SkipTests,
    [switch]$Fast,

    # The first repo to build. Default is NuGet3. This allows to us to do pseudo incremental
    # build.
    # E.g. if there are changes in NuGet.PackageManagement, then the repos we need to build
    # are NuGet.PackageManagement and NuGet.VisualStudioExtension. We don't need to build NuGet3.
    # So we can run the command as
    #     build-nuget -FirstRepo NuGet.PackageManagement
    # or
    #     build-nuget -FirstRepo pm
    #
    [ValidateSet("NuGet3", "NuGet.PackageManagement", "NuGet.VisualStudioExtension",
        "pm", "vsix")][string]$FirstRepo = "NuGet3"
)

# Build a project k project.
# - projectDirectory is the root directory of the project
# - outputDirectory is the directory where the generated nupkg files are copied to
function ProjectKBuild([string]$projectDirectory, [string]$outputDirectory)
{
    Write-Host "======== Building in $ProjectDirectory ======"

    # build the project
    pushd $projectDirectory

    if ($Fast)
    {
        # build with DNX in parallel, do not use this if there are build errors
        .\build --parallel verify
    }
    else
    {
        .\build.cmd
    }

    $result = $lastexitcode
    popd

    Write-Output "last exit code $result"
    if ($result -ne 0)
    {
        $errorMessage = "Build failed. Project directory is $projectDirectory"
        throw $errorMessage
    }

    # copy the generated nupkgs
    $artifactDirectory = Join-Path $projectDirectory "artifacts\build"
    Copy-Item (Join-Path $artifactDirectory "*.nupkg") $outputDirectory -Verbose:$true
    ls $outputDirectory NuGet.CommandLine*.nupkg | rm
}

function BuildNuGetPackageManagement()
{
    pushd "$GitRoot\NuGet.PackageManagement"
    $env:NUGET_PUSH_TARGET = $packagesDirectory
    $args = @{ Configuration = $Configuration; PushTarget = $packagesDirectory;
        Version = $Version }
    if ($SkipTests -or $Fast)
    {
        $args.Add("SkipTests", $true)
    }

    & "$GitRoot\NuGet.PackageManagement\pack.ps1" @args
    $result = $lastexitcode
	
	# ILMerge nuget.exe
	cd "$GitRoot\NuGet.PackageManagement\src\NuGet.CommandLine\bin\$Configuration"		
	if (Test-Path Merged)
	{	 
	    rmdir Merged\nuget.exe
	}
	else 
	{
	    mkdir Merged
	}
	if ($result -eq 0) 
	{
	    Write-Output "Creating the ilmerged nuget.exe"		
        & $ILMerge NuGet.exe NuGet.Client.dll NuGet.Commands.dll NuGet.Configuration.dll NuGet.ContentModel.dll NuGet.Core.dll NuGet.DependencyResolver.Core.dll NuGet.DependencyResolver.dll NuGet.Frameworks.dll NuGet.LibraryModel.dll NuGet.Logging.dll NuGet.PackageManagement.dll NuGet.Packaging.Core.dll NuGet.Packaging.Core.Types.dll NuGet.Packaging.dll NuGet.ProjectManagement.dll NuGet.ProjectModel.dll NuGet.Protocol.Core.Types.dll NuGet.Protocol.Core.v2.dll NuGet.Protocol.Core.v3.dll NuGet.Repositories.dll NuGet.Resolver.dll NuGet.RuntimeModel.dll NuGet.Versioning.dll Microsoft.Web.XmlTransform.dll Newtonsoft.Json.dll /lib:"C:\Program Files (x86)\MSBuild\14.0\Bin" /log:mergelog.txt /out:Merged\nuget.exe
	}	
    popd

    if ($result -ne 0)
    {
        throw "Build failed"
    }
}

function BuildVSExtension()
{
    pushd "$GitRoot\NuGet.VisualStudioExtension"
    $env:VisualStudioVersion="14.0"
    & msbuild build\build.proj /t:RestorePackages /p:NUGET_BUILD_FEEDS=$packagesDirectory

    if ($LASTEXITCODE -ne 0)
    {
        popd
        throw "Build failed"
    }

    & msbuild NuGet.VisualStudioExtension.sln /p:Configuration=$Configuration /p:VisualStudioVersion="14.0" /p:DeployExtension=false
    if ($LASTEXITCODE -ne 0)
    {
        popd
        throw "Build failed"
    }


    popd
}

$ilmerge = Join-Path $PSScriptRoot "ilmerge.exe"

# version number of non-k projects
$timestamp = [DateTime]::UtcNow.ToString("yyMMddHHmmss");
$Version="3.1.1-local-$timestamp"

# set environment used by k
$env:Configuration=$Configuration
$env:DNX_BUILD_VERSION="local-$timestamp"

# Create the packages directory
$GitRoot = Get-Location
$packagesDirectory = "$GitRoot\nupkgs"
if (!(Test-Path $packagesDirectory))
{
    mkdir $packagesDirectory
}

if ($FirstRepo -eq "NuGet3")
{
    # build NuGet3
    rm "$packagesDirectory\*.nupkg"
    ProjectKBuild "$GitRoot\NuGet3" "$GitRoot\nupkgs"
}

if (($FirstRepo -eq "NuGet3") -or
   ($FirstRepo -eq "NuGet.PackageManagement") -or
   ($FirstRepo -eq "pm"))
{
    # build NuGet.PackageManagement
    BuildNuGetPackageManagement
}

# build NuGet.VisualStudioExtension
BuildVSExtension

