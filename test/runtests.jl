using Test
using Markdown
using Suppressor
using SimpleClang

function test_output(code, expected)
    output = @capture_out compile_and_run(code)
    @test output == expected
end

@testset "printf" begin
    test_output(c"""
#include <stdio.h>
int main()
{
    int i = 0;
    printf("%d\n", i);
}
""", "0\n")
end

@testset "show_run_command" begin
    output = @capture_err wrap_compile_and_run(c"""
    return EXIT_SUCCESS;
    """, show_run_command = true)
    # On MacOS, it starts with "-macosx_version_min has been renamed to -macos_version_min\n[ Info:"
    # so we cannot use use `startswith`
    @test contains(output, "[ Info: Running : `")
end

@testset "codesnippet" begin
    @test codesnippet(c"""
    a;
    // codesnippet
    b;
    // codesnippet
    c;
    """) == c"""
    b;"""
end

@testset "md" begin
    code = c"""
int i = 0;
printf("%d\n", i);
    """
    md_code(code) == md"""
```c
int i = 0;
printf("%d\n", i);
```"""
end

@testset "html" begin
    @test sprint(show, MIME"text/html"(), c"int i;") == "<div class=\"markdown\"><pre><code class=\"language-c\">int i;</code></pre>\n</div>"
end

@testset "emit_llvm" begin
    @test isnothing(emit_llvm(c"""
    int i
    """))
    @test emit_llvm(c"""
    int i;
    """) isa CCode
end

@testset "wrap" begin
    for code in [
        c"""
    printf("Hello, World!\n");
    """,
        cpp"""
    printf("Hello, World!\n");
    """,
    ]
        out = wrap_compile_and_run(code)
        @test out == code
        output = @capture_out wrap_compile_and_run(code)
        @test output == "Hello, World!\n"
    end
end

const LIB = compile_lib(c"""
int increment(int i) {
  return i + 1;
}
""")[2]

@testset "compile_lib" begin
    @test ccall((:increment, LIB), Int, (Int,), 1) == 2
end
