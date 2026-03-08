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

@testset "OpenMP SIMD" begin
    file = compile(c"""
float sum(float *vec, int length) {
    float total = 0;
	#pragma omp simd
    for (int i = 0; i < length; i++) {
        total += vec[i];
    }
    return total;
}
    """, cflags = ["-fopenmp", "-O3"], lib = true, emit_llvm = true)
    llvm = read(file, String)
    @test contains(llvm, "<4 x float>")
end

# Taken from https://blegat.github.io/LINMA2710/
# Uses C (not C++) to avoid Clang_jll's clang 15 being incompatible
# with newer macOS Xcode SDK libc++ headers.
const SUM_LIB = compile(c"""
#include <stdint.h>
#include <stdlib.h>
#include <omp.h>
#include <stdio.h>

float sum(float *vec, int length, int num_threads, int verbose) {
  float total = 0;
  omp_set_dynamic(0); // Force the value `num_threads`
  omp_set_num_threads(num_threads);
  float *local_results = (float *)calloc(num_threads, sizeof(float));
  #pragma omp parallel
  {
    int thread_num = omp_get_thread_num();
	int stride = length / num_threads;
    int last = stride * (thread_num + 1);
    if (thread_num + 1 == num_threads)
      last = length;
	if (verbose >= 1)
      fprintf(stderr, "thread id : %d / %d %d:%d\n", thread_num, omp_get_num_threads(), stride * thread_num, last - 1);
	float no_false_sharing = 0;
    #pragma omp simd
    for (int i = stride * thread_num; i < last; i++)
      no_false_sharing += vec[i];
	local_results[thread_num] = no_false_sharing;
  }
  for (int i = 0; i < num_threads; i++)
    total += local_results[i];
  free(local_results);
  return total;
}
""", lib = true, cflags = ["-O3", "-mavx2", "-fopenmp"])

@testset "OpenMP multithread" begin
    c_sum(x::Vector{Cfloat}; num_threads = 1, verbose = 0) = ccall(("sum", SUM_LIB), Cfloat, (Ptr{Cfloat}, Cint, Cint, Cint), x, length(x), num_threads, verbose);
    vec = Cfloat[-1, 3, 4, 2, 5, -2, -9, 4]
    for num_threads in 1:4
        @test c_sum(vec; num_threads) == sum(vec)
    end
end
