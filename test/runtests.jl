using Test
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

@testset "compile_lib" begin
    code, lib = compile_lib(c"""
int increment(int i) {
  return i + 1;
}
""")
    @test code isa CCode
    @test ccall((:increment, lib), Int, (Int,), 1) == 2
end
