# Cross-Platform Test Debugging in VS Code

Most test suites in the NuGet codebase are able to run cross-platform on .NET Core. This guide is a walkthrough of how to debug tests on all supported platforms, as well as remotely on Linux. These instructions require VS Code.

## Setting up .NET Core

Please follow the [documentation on installing the .NET Core SDK](https://docs.microsoft.com/en-us/dotnet/core/install/sdk?pivots=os-windows) for your target operating system and architecture. For the time being, you will want version 3.1 unless you're developing something that requires .NET 5.0.

## Setting up VS Code

1. [Install VS Code](https://code.visualstudio.com/) for your desired development platform. If debugging remotely, you only need VS Code installed on the machine you're connecting _from_.
1. Install [the C# extension](https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.csharp).
1. In the root of the NuGet repo on your local machine, create a `.vscode/launch.json` file, and paste the following into it:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": ".NET Core Attach (Test)",
      "type": "coreclr",
      "request": "attach",
      "processId": "${command:pickProcess}",
      "symbolOptions": {
        "searchPaths": [
          // Change this path to the test project dll path that you want to debug, and add any additional search paths.
          "${workspaceFolder}/test/NuGet.Core.FuncTests/NuGet.Packaging.FuncTest/bin/Debug/netcoreapp5.0"
        ]
      }
    }
  ]
}
```

## Running and Debugging a Test Suite

1. Open a terminal in VS Code.
1. `cd` into the path of the test project you want to debug.
1. Edit the `searchPaths` array in your `.vscode/launch.json` to be the directory containing the assemblies of the test project you're debugging.
1. Run `dotnet build`
1. Launch the test suite in debug mode:
   1. On Windows:
      1. `$env:VSTEST_HOST_DEBUG=1` To set the environment variable.
      1. `dotnet vstest bin\debug\netcoreapp5.0\My.Test.Project.dll /Tests:<TestFilterHere>`
   1. On OSX and Linux:
      1. `VSTEST_HOST_DEBUG=1 dotnet vstest bin/debug/netcoreapp5.0/My.Test.Project.dll /Tests:<TestFilterHere>`
1. When the terminal prompts you to attach, go to the debugger tab in VS Code and launch the `.NET Core Attach (Test)` configuration, then enter the PID of the process in the terminal.
1. Once attached, resume execution _and then disconnect_, letting that part run -- we're not at the actual tests yet.
1. Once the first process completes, the terminal will prompt you _again_ to attach to a process. Lanch the attach process again and enter the _new_ PID.
1. You are now attached to the running test and can debug it, place breakpoints, inspect stack frames and values, etc. For more information on debugging using VS Code, see [its documentation](https://code.visualstudio.com/Docs/editor/debugging).

### Remote Development and Debugging Using VS Code

If you're trying to debug on a remote Linux machine, you can use [VS Code to develop and debug on a remote codebase](). When doing so, you'll need to run the `dotnet` commands in the _remote terminal_, probably in VS Code itself, _not_ on your remote machine.

## Running `sudo` commands on \*nix machines without entering a password

In some situations, you might need to run a test suite in `sudo` mode because the tests are making changes to the local system. In this case, you'll need to use `visudo` to add a line to your `sudoers` file:

1. Run `sudo visudo` and enter your login password.
1. Use the arrow keys to navigate to the line with your login username.
   1. If there's no such line, simply add the line instead of editing it (below)
1. Press the `i` key to enter "Insert mode".
1. Use the arrow keys and backspace to erase the line with your username (skip if no such line exists)
1. Press `Enter` to create a new line.
1. Enter this as your line: `$your-login-username-here ALL = (ALL) NOPASSWD: ALL`
1. Press `Escape` to leave insert mode.
1. Type `:wq` and press `Enter` to exit `visudo`.

For more information on vi keybindings, please go to [this documentation](https://www.linux.com/training-tutorials/vim-101-beginners-guide-vim/).
