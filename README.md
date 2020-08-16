# zasm
zasm is a basic MIPS assembler for the R3400 CPU.

## Usage

```
lua zasm.lua [-o out_file] [-p patch_name] [-l mips_line...] files...
```

The assembler generates output byte code from input files and input lines from the `-l` option. The output code is always shown in the console. It can also be written to an output file specified by the `-o` option. Moreover, the assembler can generate a [Hexo](github.com/kroemker/Hexo) patch file. The memory location of output bytes can be set using the `.rom` macro.
