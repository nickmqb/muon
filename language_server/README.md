## Muon language server

The Muon language server enables interactive compiler features during development. It implements (a subset of) the [Language Server Protocol](https://microsoft.github.io/language-server-protocol/).

Currently, the following features are implemented:
* Symbol search  
![alt text](https://github.com/nickmqb/vscode-muon/blob/master/symbol-search.gif "Symbol search")
* Go to definition  
![alt text](https://github.com/nickmqb/vscode-muon/blob/master/go-to-definition.gif "Go to definition")
* As-you-type diagnostics (i.e. "live error feedback")  
![alt text](https://github.com/nickmqb/vscode-muon/blob/master/error-feedback.gif "Error feedback")

Note: the language server is in a pre-alpha state. You may encounter some rough edges.

### Supported editors

Any editor that supports the the Language Server Protocol can use the language server (if you run into issues with your editor, please file a bug).

Each editor will likely require a bit of configuration and/or glue code to make everything work. This configuration/glue code can usually be packaged as an editor extension/plugin to easily allow people to use the language server for that particular editor. Examples (just one currently):

* [vscode-muon](https://github.com/nickmqb/vscode-muon), by [nickmqb](https://github.com/nickmqb) (Muon author): for VSCode. Syntax highlighting, language features (via language server).

Other extensions that do not (yet) support the language server:

* [muon-mode](https://github.com/pgervais/muon-mode/blob/master/muon-mode.el), by [pgervais](https://github.com/pgervais): for Emacs. Syntax highlighting, indentation.

If you've created a Muon extension for an editor and would like me to include the extension here, let me know.

### Build

1. Navigate to the `language_server` directory
2. Compile:
	* On Linux/macOS: `mu --args language_server.args`
	* On Windows: `mu --args language_server_win32.args`
3. Compile the resulting `language_server.c` file with a C compiler of your choice

**Important note for Windows users**: You _must_ use `language_server_win32.args` (`language_server.args` will compile, but the server will not work properly).

### Run

The server takes a single command line argument: `--args [path]`. This must be the path of a `.args` file that would normally be passed to the compiler. E.g.: `language_server --args hello_world.args`

The source files that are listed in the args file will be processed by the language server. Source files not listed in the args file don't get language server support.

Note! The args path must be a relative path that does not contain any spaces. It must be relative to the `rootPath` provided by the editor in the `initialize` message. For example, in VSCode the rootPath is path of the first folder in the workspace. Also, all source file paths in the args file must be relative paths.

The args file is not read until the server receives an `initialize` message from the language client (editor).

You'd normally configure your editor to start the language server on demand (e.g. when the editor encounters a `.mu` file). For an example, see [vscode-muon](https://github.com/nickmqb/vscode-muon).

### Troubleshooting

The server prints status messages to `stderr`. Further error reporting for language server errors/configuration errors is still TODO (and not great at the moment: currently the server mostly just abandons upon encountering an unexpected input/situation). If the problem persists, feel free to file a bug.