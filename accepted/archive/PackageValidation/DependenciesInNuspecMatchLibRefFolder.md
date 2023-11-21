# Dependency Group Target Frameworks Must Match `/lib` and `/ref` assets

* Status: **Developing**
* Author(s): [Joshua Silas](https://github.com/JarahSi)

## Issue

[8254](https://github.com/NuGet/Home/issues/8254) - Validation for depency groups in a package's nuspec by Target Framework (TFM)

## Background

Currently, TFMs are declared in multiple places in the packages. However, some packages declare more TFMs in one location than in the other, such as in the .nuspec or in the `/lib` or `/ref` folders. This can lead to any number of these situations:

* The package does not show dependencies by TFM on nuget.org, and package consumers have more difficulty finding compatible packages on NuGet.

* NuGet will not know about these required dependencies and not install them, which will lead to errors in the project at runtime, such as load errors.

* The package does not contain the the .dll files for the TFMs the .nuspec claims it has and encounters compiler errors.

This inconsistency in packages means that important information is not being relayed to the customer.

Currently, this mistake only occurs in `nuget pack` and `dotnet pack` with custom nuspec files. With VS and csproj pack, it automatcally sorts them. However, multitargeting only works with SDK style projects, while older projets need multiple csproj files.

|               | .nuspec | .csproj |
|---------------|------------|---------|
|  `nuget pack` | X | success (hard to multitarget) |
| `dotnet pack` | X | success |
| Visual Studio --> build --> pack| N/A| success |

## Who are the customers

This will directly affect package authors. However, this change will have a positive effect on package consumers' ability to discover packages.

## Requirements

* A method of notifying package authors of this inconsistency in the package during pack

## Solution
### Guarantee Dependency Resolution
One possible solution we could implement is to look into the package's assemblies and extract its assembly references. The validation would resolve the dependencies then check all the packages from that dll. If it can't be found, the warning is raised.

There are some problems with this solution:
1. If the current packages and the dependent packages are new, than the validator won't be able to find it anywhere
2. Even if it does, it might not be in the current sources

This is technically possible but it would be slow and difficult to implement, so it is best left out.

# Proposal
The proposed solution is to create a rule that looks inside a package's dependency groups (in the .nuspec file) and its `/lib` and `/ref` folders and evaluate whether the TFMs in each are the same. This rule would run at `nuget pack` so that we can stop packages from being incorrectly packed.  The goal of the rule is to increase the chance that a package will declare all of its dependencies for each TFM, which helps consumers determine if a package is compatible with their project.

There are 5 states that a package can adhere to:
1. The nuspec has a dependency group that the `/lib` or `ref` folder does not have

      * in the nuspec:
          ```
          <dependencies>
            <group targetFramework = ".NETFramework4.5" />
            <group targetFramework = ".NETStandard1.3">
                <dependency id = ... />
            </group>
          </dependencies>
          ```
      * in the package `/lib` folder:
          ```
          /lib
            /netstandard1.3
           ```

2. The `/lib` folder has a dependency group that the nuspec does not have
      * in the nuspec:
          ```
          <dependencies>
            <group targetFramework = ".NETStandard1.3">
                <dependency id = ... />
            </group>
          </dependencies>
          ```
      * in the package `/lib` folder:
          ```
          /lib
            /net45
            /netstandard1.3
           ```
3. The nuspec and `/lib` folder  each have elements that don't exist in the other (esentially the first two issues happening simultaneously
      * in the nuspec:
          ```
          <dependencies>
          <group targetFramework = ".NETFramework4.5" />
            <group targetFramework = ".NETStandard1.3">
                <dependency id = ... />
            </group>
          </dependencies>
          ```
      * in the package `/lib` folder:
          ```
          /lib
            /net40
            /netstandard1.3
           ```
4. No warning is raised because:
  * The nuspec matches the `/lib` folder completely
     * in the nuspec:
          ```
          <dependencies>
          <group targetFramework = ".NETFramework4.5" />
            <group targetFramework = ".NETStandard1.3">
                <dependency id = ... />
            </group>
          </dependencies>
          ```
      * in the package `/lib` folder:
          ```
          /lib
            /net45
            /netstandard1.3
  * Both the nuspec and `/lib` folder don't declare dependency groups
    * The nuspec doesn't have a `<dependencies>` element
    * in the package `/lib` folder:
        ```
        /lib
          /test.dll
         ```   
         * we should ensure that the `/lib/foo.dll` is caught by another rule. This rule will not raise a problem
5. There is a mismatch between the two, but the mismatched TFM in the `/lib` and `/ref` folders are compatible with one of the TFMs in the nuspec (This compatibility check only works from package to nuspec)
  * in the nuspec:
       ```
       <dependencies>
       <group targetFramework = ".NETFramework4.5" />
         <group targetFramework = ".NETStandard1.3">
             <dependency id = ... />
         </group>
       </dependencies>
       ```
  * in the package `/lib` folder:
       ```
       /lib
         /net472
         /netstandard1.3
       ```  
       
For the first three scenarios, there is a disconnect between the nuspec and the `/lib` folder. The `/lib` folder has subdirectories titled after the frameworks that it's compatible with. The nuspec has a list of dependency groups for each TFM supported by the package.

The rule would check for `/lib` and `/ref` folders, see what frameworks are supported, and store them in a list. It then looks at the .nuspec file's `<dependencies>` for its compatible TFMs, which it stores in a second list. For each mismatched element, the warning code `NU5128` is thrown, with the warning message (W1) warning the user of the behavior and advising said user to make changes to the offending asset, whether it's the nuspec, the nupkg, or both. If the fifth scenario is true a second warning (W2) with error code `NU5130` is thrown, if there is a compatible match, but not an exact match (There is a second option whre it's treated as a separate error code for any future refactoring, such as allowing for rules to be turned off).

Essentially, this chart has the flow:

| nuspec contains/package contains | `lib/foo.dll` | `lib/net45/foo.dll` | `lib/net45 and lib/ns20` | `lib/net472` |
|----------------------|-------------------------|-----------------------|------------------------|--------------------|
| dependency node with no TFM group | no warning | show W1 | show W1| show W1 |
| dependency node with only net45 group | show W1 | no warning | show W1 | show W1 and W2 |
| dependency node with net45 and ns20 group | show W1 | show W1 | no warning |show W1 and W2 |


The warning message for W1 is:
```
The TFM <tfm> in <location of the TFM> does not have a exact match in the {location where it is missing}. 
Please add a reference to this TFM in the {location where it is missing}.
```

The warning message for W2 is:

```
The TFM <tfm> in <location of the TFM> does have a compatible match in the {location where it is missing},
but does not have an exact match. Please add a reference to this TFM in the {location where it is missing}.
```
