# `build.props` or `build.targets` File Doesn't Follow Covention

* Status: **Unstarted**
* Author(s): [Joshua Silas](https://github.com/JarahSi)

## Issue
[8295](https://github.com/NuGet/Home/issues/8295) - Validation for `build.props` convention in the package.

## Background

Currently, the build folder contains either `props` or `targets` files that are compatible with all TFMs or folders for each supported TFM that contain the corresponding `props` or `targets` files. However, the convention for this file states that the file name should be `<package_id>.props` or `<package_id>.targets`. As such, there are packages that ignore this convention, and the props and target files are ignored. 

This problem only appears when package authors edit a package's ID without addressing the build files, or creating a props file for the first time with no knowledge of the convention.
## Who are the customers

Package authors

## Requirements

- a method of warning authors that the package is ignoring the `build.props` convention

## Proposal
I propose a rule that would throw a warning if there is not at least one `props` file (if any are present) and one `targets` file (if any are present) in the `/build` folder follow the convention. This rule will run at `nuget pack` and return the warning code `NU5129`

In a package with the ID `test.package` you have:
  ```
  /lib
  /build
    /net45
      /test.package.props
      /test.package.targets
    /netstandard2.0
      /test.package.props
      /test.package.targets
  ```
The rule would check to make sure that each subfolder (if applicable) in `/build` contains at least 1 `.props` or `.targets` file that follows the `<package_id>.props` convention. In the example above, the warning would not be raised as it follows the build convention for each declared TFM.

However, a package with the ID `My.Package` contains
  ```
  /lib
  /build
    /net45
      /My.Package.props
    /netstandard2.0
      /MyPackage.props
  ```
The rule would see that the `/netstandard2.0` folder doesn't conatin any `.props` or `.targets` files that follow the convention and therefore raise an `NU5129` which states:

```
A props file was found in build/netstandard2.0/. However, this file is not My.Package.props. Change the file to fit this format. 
```
          
In a package with the ID `Package.All.Compat`, you have:

  ```
  /lib
  /build
    /Package.All.Compat.props
  ```
This won't raise any errors as because there are no subfolders to check and there is a props file that follows the convention. In this next case:

  ```
  /lib
  /build
    /Package.All.Compatible.props
  ```
The warning will trigger with this warning message:

```
A props file was found in build/. However, this file is not named Package.All.Compat.props. Change the file to fit this format. 
```

