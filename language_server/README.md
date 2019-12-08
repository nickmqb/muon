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

For more GIFs, [see below](#more-gifs).

If you've created a Muon extension/plugin for an editor, or if you have written instructions on how to use Muon with an editor (possibly using an existing plugin for that editor), feel free to let me know and I'll include a link here.

### Build

1. Navigate to the `language_server` directory
2. Compile:
	* On Linux/macOS: `mu --args language_server_linux_macos.args`
	* On Windows: `mu --args language_server_windows.args`
	* _Note_: make sure to use the right file for your OS, otherwise the language server may compile, but may not work properly.
3. Compile the resulting `language_server.c` file with a C compiler of your choice

### Run

The server requires a single command line argument: `--args [path]`. This must be the path of a `.args` file that would normally be passed to the compiler. E.g.: `language_server --args hello_world.args`

The source files that are listed in the args file will be processed by the language server. Source files not listed in the args file don't get language server support.

_Note_: Relative .args paths and relative source file paths (inside the .args file) will be interpreted as being relative to the 'root path', which is provided by the editor and sent to the language server. For example, VS Code sets the root path to the path of the first folder in the workspace. You can override the root path with `--root-path [path]`.

### Troubleshooting

If you specify the command line argument `--log-stderr`, the server will log detailed status messages to `stderr`. If you specify `--log-file`, the server will log status messages to the file `muon_language_server.log` in the current directory. If you find any bugs, [please let me know](https://github.com/nickmqb/muon/issues).

### More information

You may also be interested in [my blog post on the design process of the Muon language server](https://nickmqb.github.io/2019/11/24/building-a-language-server-for-muon.html). Also, to stay up-to-date on Muon, consider [following me on Twitter](https://twitter.com/nickmqb).

### More GIFs

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