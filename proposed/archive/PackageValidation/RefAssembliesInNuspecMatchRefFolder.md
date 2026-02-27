# Validate that Reference Assemblies in Nuspec are present in the `/ref` Folder and Vice Versa

* Status: **Unstarted**
* Author(s): [Joshua Silas](https://github.com/JarahSi)

## Issue
[8296](https://github.com/NuGet/Home/issues/8296) - Validation for ref assemblies in nuspec and `ref` folder 

## Background

In the nuspec, there is a `<references>` element that lists the assemblies that are meant for compile time specifically. This correpsonds to the reference dlls found in the `/ref` folder.

Here is a sample nuspec with a `<references>` node:
```
<references>
    <group targetFramework="net472">
        <reference file="MyLib.dll" />
        <reference file="MyHelpers.dll" />
    </group>
</references>
```

and here is a sample package directory:
```
lib\
  net472\
    MyLib.dll
    MyHelpers.dll
    MyUtilities.dll
ref\
  net472\
    MyLib.dll
    MyHelpers.dll
```

Here you can see that files mentioned in the nuspec are present in the `ref/` folder. However, if the nuspec and the `ref/` folder are inconsistent with each other, there can be issues.

* In `package.config` (PC) projects
    * PC projects don't ultilize the `ref/` folder if there is a reference section defining assets
* In `PackageReference` (PR) projects
    * PR projects, by default, use `lib/` assets as runtime assets. If there are any `ref/` assets, they're used for compile time; if not, then `lib/` assets are used for compile time.
        * If there are references in the nuspec, it uses those for compile time.
        * The main problem: if a project is downgraded from `PackageReference` (PR) project to a PC project, there will be compile errors
    * There is a bug where a package contains only `lib/` assets, and a `<references>` node in the nuspec. This bug causes only the references to be used for both compile and runtime, instead of using all lib assets at runtime.
        * The project will crash at runtime due to the files it's looking for being missing

## Who are the customers

- Package authors

## Requirements

- Warn the author that the references in the nuspec have not been found in the `/ref` folder

## Proposal

The proposed solution is a rule that would validate that a package with a `references` node in the nuspec contains those libraries in  the `ref/` folder. This rule would be run during `pack` and have an associated warning code of `NU5131`.

### Expected Package

This is an example of a correct package. The nuspec contains:
```
<references>
    <group targetFramework="net472">
        <reference file="MyLib.dll" />
        <reference file="MyHelpers.dll" />
    </group>
</references>
```
and the package contains:
```
lib\
  net472\
    MyLib.dll
    MyHelpers.dll
    MyUtilities.dll
ref\
  net472\
    MyLib.dll
    MyHelpers.dll
```

The compile items in this case would be  `MyLib.dll` and `MyHelpers.dll`. The rule would consider this correct and not raise any warnings, because it contains both files in the `references` node and in the `ref/` folder. 

### File called in nuspec is not found in the `ref/`
However, an incorrect instance would contain a nuspec:
```
<references>
    <group targetFramework="net472">
        <reference file="MyLib.dll" />
        <reference file="MyHelpers.dll" />
    </group>
</references>
```

and the package itself contains:
```
lib\
  net472\
    MyLib.dll
    MyHelpers.dll
    MyUtilities.dll
ref\
  net472\
    MyHelpers.dll
```

The rule will see that the directory `ref/net472` doesn't contain the file `MyLib.dll`, and raise the warning code `NU5131`.

### File called in `ref/` is not found in the nuspec

This would follow the same logic as the previous scenario. There needs to be an exact match.
This type of validation will only occur if the nuspec has a `references` element

### Validation for each subfolder

This rule will ensure that every target framework has the correct reference dlls in it.

For example this nuspec cotains:
```
<references>
    <group targetFramework="net472">
        <reference file="MyLib.dll" />
        <reference file="MyHelpers.dll" />
    </group>
    <group targetFramework="net45">
        <reference file="MyLib.dll" />
        <reference file="MyHelpers.dll" />
    </group>
    <group targetFramework="net462">
        <reference file="MyLib.dll" />
        <reference file="MyHelpers.dll" />
    </group>
</references>
```

then the package would contain:
```
ref\
  net472\
    MyLib.dll
    MyHelpers.dll
  net462\
    MyLib.dll
    MyHelpers.dll
  net45\
    MyLib.dll
    MyHelpers.dll    
```

### Warning Code
The associated warning code `NU5131` will be raised once and will have a warning message that references each mistake:

> References were found in the nuspec, but some were not found within the ref folder. Add the following reference assemblies:
{list of missing dlls and what folder they were omitted from}
