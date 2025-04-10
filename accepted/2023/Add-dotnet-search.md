# **Add `search` Functionality to DotNet**
<!-- Replace `Title` with an appropriate title for your design -->

- [Nigusu](https://github.com/Nigusu-Allehu) <!-- GitHub username link -->
- [GitHub Issue](https://github.com/NuGet/Home/issues/6060) <!-- GitHub Issue link -->

## Summary

<!-- One-paragraph description of the proposal. -->
The specification seeks to add search functionality to dotnet. The functionality will be added to dotnet as a search command: `dotnet package search`.  

## Motivation

<!-- Why are we doing this? What pain points does this solve? What is the expected outcome? -->
Customers have expressed a desire for the functionality of the nuget.exe list command to be integrated into the dotnet CLI. Here is a discussion on the request: [NuGet/Home#6060](https://github.com/NuGet/Home/issues/6060). By implementing the search feature, we can effectively address this need, as it will allow users to retrieve and display a list of packages, thereby achieving the primary objective of the list command in a more streamlined manner within the dotnet environment.The [NuGet Server API Search Resource specification requires all packages to be returned when no `q` parameter is provided](https://learn.microsoft.com/en-us/nuget/api/search-query-service-resource#request-parameters). Therefore, this proposal does not add a `list` equivalent to the `dotnet` CLI, as it is effectively redundant.

## Explanation

### Functional explanation

<!-- Explain the proposal as if it were already implemented and you're teaching it to another person. -->
<!-- Introduce new concepts, functional designs with real life examples, and low-fidelity mockups or  pseudocode to show how this proposal would look. -->
Imagine you have your dotnet CLI open. You would like to look up a NuGet package named `MyPackage` from a source `<MySource>`. No worries, you can just use the following command : `dotnet package search MyPackage --source <MySource>`. It will provide you with the table of the packages in the source `<MySource>` that match with the search criteria. This output will have the search term used highlighted in the search result.

The `package search [search terms] [options]` command will have the following options

| Option           | Function |
|------------------|--------------|
| `--configfile`   | The path to the NuGet config file to use. |
| `--exact-match`  | Return exact matches only as a search result. |
| `--format`       | Format the output accordingly. Either `table`, or `json`. The default value is `table`. |
| `--help`         | Show command help and usage information. |
| `--interactive`  | Allows the command to stop and wait for user input or action (for example to complete authentication).|
| `--prerelease`   | Allow prerelease packages to be shown. |
| `--skip`         | The number of results to skip, for pagination. The default value is 0. |
| `--source`       | A source to search. |
| `--take`         | The number of results to return. The default value is 20.|

#### **Option `--source`**

This option will specify a list of sources to search from. If a source is not specified using this option, the sources in the `nuget.config` file will be used.

#### **Option `-exact-match`**

- This option will allow for users to be able to search and have only exact matches as an output.
- The results will contain all versions of the matching package ID
- For example if a user uses `dotnet package search Newtonsoft.Json`

        Source: nuget.org
        | Package ID                                  | Latest Version | Owners | Total Downloads |
        |---------------------------------------------|----------------|---------|-----------------|
        | Newtonsoft.Json                             | 13.0.3         |         | 3,829,822,911   |
        | Newtonsoft.Json.Bson                        | 1.0.2          |         | 554,641,545     |
        | Newtonsoft.Json.Schema                      | 3.0.15         |         | 39,648,430      |
        | Microsoft.AspNetCore.Mvc.NewtonsoftJson     | 7.0.12         |         | 317,067,823     |
        ...

- Using ``dotnet package search Newtonsoft.Json --exact-match`` on the other side will have the following output

        Source: nuget.org
        | Package ID                                  |  Version | Owners | Total Downloads |
        |---------------------------------------------|----------|---------|-----------------|
        | Newtonsoft.Json                             | 13.0.3   |         | 3,829,822,911   |

#### **Option `--format`**

This option will allow the specification of the output format. The option will take one of these two arguments: `table`, or `json`. The outputs will depend on verbosity. The following examples are for normal verbosity.

- `--format table` the output will be in a tabular form as shown below

        Source: nuget.org
        | Package ID                                  | Latest Version | Owners | Total Downloads |
        |---------------------------------------------|----------------|---------|-----------------|
        | Newtonsoft.Json                             | 13.0.3         |         | 3,829,822,911   |

- `--format json` : A json output will be outputted. It will contain the following metadata.
  - Source
  - Package ID
  - LatestVersion
  - Owners
  - TotalDownloads

  The output will take the following format.

      {
        "version": 1,
        "problems": [
          {
            "level": "error",
            "text": "An error occurred!"
          }
        ],
        "searchResult": [
          {
            "source": "source Name1",
            "problems": [
              {
                "level": "error",
                "text": "An error occurred!"
              }
            ],
            "packages": [
              {
                "Owners": "",
                "totalDownloads": "",
                "latestVersion": "",
                "id": ""
              }
            ]
          },
          {
            "source": "source Name2",
            "problems": [
              {
                "level": "error",
                "text": "An error occurred!"
              }
            ],
            "packages": [
              {
                "Owners": "",
                "totalDownloads": "",
                "latestVersion": "",
                "id": ""
              }
            ]
          },...
        ]
      }

##### Error Handling

The `problems` section captures and reports issues, and it appears in two contexts: globally for the command and individually for each source. `problems` has two sections: `level` and `text`. Whether a problem is an error or a warning is presented in `level`. And the message describing the problem is presented in `text`.

- **Global Problems**: Here, `problems` detail issues that prevent the command from proceeding. These are critical errors that affect the entire operation.
- **Source-Specific Problems**: Within each source, `problems` identify issues related only to that source. These might include source errors, or other source-specific issues."


#### Option `--verbosity`

  controls the amount of information included in the output of a command. This allows you to tailor the output to your needs, providing either a concise summary or a detailed breakdown of the information returned by the command.

Here are the details of each verbosity level:

- **`--verbosity minimal`** : The output will contain minimal information. For each package, it will display only the following metadata:
  - Package ID
  - Latest Version
  
- **`--verbosity normal`** : The output will provide a moderate amount of information. For each package, it will display the following metadata:
  - Package ID
  - Latest Version
  - Owners
  - Total Downloads
  
- **`--verbosity detailed`** : The output will be highly detailed. For each package, it will display the following metadata:
  - Package ID
  - Latest Version
  - Owners
  - Total Downloads
  - Description
  - Deprecation
  - Project URL

### Technical explanation

<!-- Explain the proposal in sufficient detail with implementation details, interaction models, and clarification of corner cases. -->
This command will prepare a search parameter using the inputs of  `Search Term`, `--take`, and `--prerelease`.
This parameter is then used prepare an API query to the specified source. Nuget.Protocol will be used to do this query. Then the result is printed accordingly. If `--exact-match` is specified, the get metadata API is used to load the metadata for the specific package.

## Drawbacks

<!-- Why should we not do this? -->

## Rationale and alternatives

<!-- Why is this the best design compared to other designs? -->
<!-- What other designs have been considered and why weren't they chosen? -->
<!-- What is the impact of not doing this? -->
In nuget.exe there is `nuget.exe search` command which does the same thing. However, customers would like this functionality to be available in dotnet.

## Prior Art

<!-- What prior art, both good and bad are related to this proposal? -->
<!-- Do other features exist in other ecosystems and what experience have their community had? -->
<!-- What lessons from other communities can we learn from? -->
<!-- Are there any resources that are relevant to this proposal? -->

## Unresolved Questions

<!-- What parts of the proposal do you expect to resolve before this gets accepted? -->
<!-- What parts of the proposal need to be resolved before the proposal is stabilized? -->
<!-- What related issues would you consider out of scope for this proposal but can be addressed in the future? -->

## Future Possibilities

