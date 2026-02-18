using Test
using Suppressor
using SimpleClang

function test_output(code, expected)
    compile_and_run(code, verbose = 1)
    output = @capture_out compile_and_run(code)
    # Normalize line endings (Windows uses CRLF)
    output = replace(output, "\r\n" => "\n")
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
