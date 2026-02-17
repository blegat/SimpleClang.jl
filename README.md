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
