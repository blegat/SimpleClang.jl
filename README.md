# SimpleClang.jl

[![Build Status](https://github.com/blegat/SimpleClang.jl/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/blegat/SimpleClang.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/blegat/SimpleClang.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/blegat/SimpleClang.jl)

## Installation

Install SimpleClang as follows:
```julia
import Pkg
Pkg.add("SimpleClang")
```
In a Pluto notebook, `using SimpleClang` is sufficient, [it will automatically get installed](https://plutojl.org/en/docs/packages/).

> [!WARNING]
> It does not work yet on Windows. If you are running on Windows, use [WSL](https://learn.microsoft.com/en-us/windows/wsl/install).

## Usage

The main usage is to call `compile_and_run` from a simple C code.
The code is then saved to a temporary file, compile and run.
The function returns the code itself which is then nicely displayed if for example called from a Pluto cell.
```julia
julia> using SimpleClang

julia> code = c"""
       #include <stdio.h>
       int main()
       {
           int i = 0;
           printf("%d\n", i);
       }
       """
CCode("#include <stdio.h>\nint main()\n{\n    int i = 0;\n    printf(\"%d\\n\", i);\n}\n")

julia> compile_and_run(code)
0
CCode("#include <stdio.h>\nint main()\n{\n    int i = 0;\n    printf(\"%d\\n\", i);\n}\n")

julia> md_code(code)
  #include <stdio.h>
  int main()
  {
      int i = 0;
      printf("%d\n", i);
  }

julia> show(stdout, MIME"text/html"(), code)
<div class="markdown"><pre><code class="language-c">#include &lt;stdio.h&gt;
int main&#40;&#41;
&#123;
    int i &#61; 0;
    printf&#40;&quot;&#37;d\n&quot;, i&#41;;
&#125;</code></pre>
</div>
```

When showing the code in a Pluto notebook, you might want to remove boilerplate
code and only focus on the important part.
This is possible with `codesnippet` that remove code before (and including) the first and after (and including) the last line containing `codesnippet`.
```julia
julia> code = c"""
       #include <stdio.h>
       int main()
       { // codesnippet
           int i = 0;
           printf("%d\n", i);
       } // codesnippet
       """
CCode("#include <stdio.h>\nint main()\n{ // codesnippet\n    int i = 0;\n    printf(\"%d\\n\", i);\n} // codesnippet\n")

julia> md_code(codesnippet(code))
      int i = 0;
      printf("%d\n", i);

julia> md_code(compile_and_run(code))
0
      int i = 0;
      printf("%d\n", i);
```

You can also avoid writing the boilerplate code altogether with `wrap_compile_and_run`:
```julia
wrap_compile_and_run(c"""
       printf("Hello world\n");
       """)
Hello world
CCode("printf(\"Hello world\\n\");\n")
```
This wraps the code in a `main` function, automatically detects that `stdio.h` is needed and add it,
run this extended code but only return your snippet to hide the added boilerplate part.
You can see what was added with `wrap_in_main`:
```julia
julia> wrap_in_main(c"""
       printf("Hello world\n");
       """)
CCode("#include <stdio.h>\nint main(int argc, char **argv) {\n  printf(\"Hello world\\n\");\n}\n")

julia> wrap_in_main(c"""
       int *p = (int*) malloc(4 * sizeof(int));
       """)
CCode("#include <stdlib.h>\nint main(int argc, char **argv) {\n  int *p = (int*) malloc(4 * sizeof(int));\n}\n")
```

You can also compile C function in library and easily call them from Julia.
```julia
julia> code, lib = compile_lib(c"""
       int increment(int i) {
         return i + 1;
       }
       """)
(CCode("int increment(int i) {\n  return i + 1;\n}\n"), "/tmp/jl_cfdpYw/lib.so")

julia> ccall((:increment, LIB), Int, (Int,), 1)
2
```
