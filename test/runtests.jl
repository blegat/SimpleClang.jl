using Test
using Suppressor
using SimpleClang

function test_output(code, expected)
    compile_and_run(code, verbose = 1)
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
