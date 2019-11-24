## Muon language server

The Muon language server enables interactive compiler features during development. It implements (a subset of) the [Language Server Protocol](https://microsoft.github.io/language-server-protocol/).

Currently, the following features are implemented:
* Symbol search  
* Go to definition  
* As-you-type diagnostics (i.e. "live error feedback")  

### Supported editors

Any editor that supports the the Language Server Protocol can use the language server. If you run into issues with your editor, [please file a bug](https://github.com/nickmqb/muon/issues).

Some examples:

* VS Code, via [vscode-muon](https://github.com/nickmqb/vscode-muon), by [nickmqb](https://github.com/nickmqb) (Muon author). Also includes syntax highlighting.  
![alt text](https://github.com/nickmqb/vscode-muon/blob/master/symbol-search.gif "Symbol search in VS Code")

* VIM, using [vim-lsc](https://github.com/natebosch/vim-lsc).  
![alt text](https://github.com/nickmqb/muon/blob/master/docs/vim-symbol-search.gif "Symbol search in VIM")

For more screenshots, [see below](#more-screenshots).

If you've created a Muon extension/plugin for an editor, or if you have written instructions on how to use Muon with an editor (possibly using an existing plugin for that editor), feel free to let me know and I'll include a link here.

### Build

1. Navigate to the `language_server` directory
2. Compile:
	* On Linux/macOS: `mu --args language_server.args`
	* On Windows: `mu --args language_server_win32.args`
3. Compile the resulting `language_server.c` file with a C compiler of your choice

**Important note for Windows users**: You _must_ use `language_server_win32.args` (`language_server.args` will compile, but the server will not work properly).

### Run

The server requires a single command line argument: `--args [path]`. This must be the path of a `.args` file that would normally be passed to the compiler. E.g.: `language_server --args hello_world.args`

The source files that are listed in the args file will be processed by the language server. Source files not listed in the args file don't get language server support.

**Important notes**: The args path _must not contain any spaces_. If you specify a relative path, it will be interpreted as being relative to the `rootPath`, which is provided by the editor and sent to the language server. For example, VS Code sets the rootPath to the path of the first folder in the workspace. Also, all source file paths in the args file _must be relative paths_.

### Troubleshooting

If you specify the command line argument `--log-stderr`, the server will log detailed status messages to `stderr`. If you specify `--log-file`, the server will log status messages to the file `muon_language_server.log` in the current directory. If you find any bugs, [please let me know](https://github.com/nickmqb/muon/issues).

### More screenshots

#### VS Code

Symbol search  
![alt text](https://github.com/nickmqb/vscode-muon/blob/master/symbol-search.gif "Symbol search")

Go to definition  
![alt text](https://github.com/nickmqb/vscode-muon/blob/master/go-to-definition.gif "Go to definition")

Error feedback  
![alt text](https://github.com/nickmqb/vscode-muon/blob/master/error-feedback.gif "Error feedback")

#### VIM

Symbol search  
![alt text](https://github.com/nickmqb/muon/blob/master/docs/vim-symbol-search.gif "Symbol search")

Go to definition  
![alt text](https://github.com/nickmqb/muon/blob/master/docs/vim-go-to-definition.gif "Go to definition")

Error feedback  
![alt text](https://github.com/nickmqb/muon/blob/master/docs/vim-error-feedback.gif "Error feedback")