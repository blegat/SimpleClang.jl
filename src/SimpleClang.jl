module SimpleClang

import Clang_jll
import LLD_jll
import LLVMOpenMP_jll
import Clang
import Markdown
import MultilineStrings
import InteractiveUtils

abstract type Code end

struct CCode <: Code
    code::String
end

macro c_str(s)
    return :($CCode($(esc(s))))
end

struct CppCode <: Code
    code::String
end

macro cpp_str(s)
    return :($CppCode($(esc(s))))
end

struct CLCode <: Code
    code::String
end

macro cl_str(s)
    return :($CLCode($(esc(s))))
end

source_extension(::CCode) = "c"
source_extension(::CppCode) = "cpp"
source_extension(::CLCode) = "cl"

compiler(::CCode, mpi::Bool) = mpi ? "mpicc" : "clang"
function compiler(::CppCode, mpi::Bool)
    @assert !mpi
    return "clang++"
end

inline_code(code::AbstractString, ext::String) = HTML("""<code class="language-$ext">$code</code>""")
inline_code(code::Code) = inline_code(code.code, source_extension(code))

function md_code(code::AbstractString, ext::String)
    code = "```" * ext * '\n' * code
    if code[end] != '\n'
        code *= '\n'
    end
    return Markdown.parse(code * "```")
end
md_code(code::Code) = md_code(code.code, source_extension(code))
function Base.show(io::IO, m::MIME"text/html", code::Code)
    return show(io, m, md_code(code))
end

function compile(
    code::Code;
    lib,
    emit_llvm = false,
    cflags = ["-O3"],
    mpi::Bool = false,
    use_system::Bool = mpi || "-fopenmp" in cflags, # On Github action, I get `error: unknown type name 'uintptr_t'` with LLVMOpenMP_jll but it works locally
    verbose = 0,
)
    path = mktempdir()
    main_file = joinpath(path, "main." * source_extension(code))
    bin_file = joinpath(path, ifelse(emit_llvm, "main.llvm", ifelse(lib, "lib.so", "bin")))
    write(main_file, code.code)
    args = Clang.get_default_args()
    args = String[]
    if !use_system && code isa CppCode
        # `clang++` is not part of `Clang_jll`
        push!(args, "-x")
        push!(args, "c++")
    end
    append!(args, cflags)
    # On Windows, clang defaults to MSVC link.exe and can hang if it's missing; use LLD instead.
    if !use_system && Sys.iswindows()
        push!(args, "-fuse-ld=lld")
    end
    if lib
        push!(args, "-fPIC")
        push!(args, "-shared")
    end
    if emit_llvm
        push!(args, "-S")
        push!(args, "-emit-llvm")
    end
    include_dir = normpath(Clang_jll.artifact_dir, "include")
    push!(args, "-I$include_dir")
    # Clang_jll's clang doesn't know the macOS SDK path; add -isysroot so system headers (e.g. stdio.h) are found.
    if !use_system && Sys.isapple()
        sdk_path = try
            readchomp(pipeline(`xcrun --show-sdk-path`, stderr=devnull))
        catch
            ""
        end
        if !isempty(sdk_path) && isdir(sdk_path)
            push!(args, "-isysroot")
            push!(args, sdk_path)
        end
    end
    if "-fopenmp" in cflags && !use_system
        dir = LLVMOpenMP_jll.artifact_dir
        push!(args, "-I$(dir)/include")
        push!(args, "-L$(dir)/lib")
    end
    push!(args, main_file)
    push!(args, "-o")
    push!(args, bin_file)
    try
        if use_system
            cmd = Cmd([compiler(code, mpi); args])
            if verbose >= 1
                @info("Compiling : $cmd")
            end
            run(cmd)
        else
            Clang_jll.clang() do exe
                cmd = Cmd([exe; args])
                if verbose >= 1
                    @info("Compiling : $cmd")
                end
                # On Windows, -fuse-ld=lld requires lld-link on PATH; Clang_jll doesn't ship LLD (see Yggdrasil L/LLVM/common.jl clangscript).
                if Sys.iswindows()
                    lld_tools = joinpath(LLD_jll.artifact_dir, "tools")
                    path_sep = ";"
                    env = merge(ENV, "PATH" => lld_tools * path_sep * get(ENV, "PATH", ""))
                    run(setenv(cmd, env))
                else
                    run(cmd)
                end
            end
        end
    catch err
        if err isa ProcessFailedException
            @warn(sprint(showerror, err))
            return
        else
            rethrow(err)
        end
    end
    return bin_file
end

function emit_llvm(code; kws...)
    llvm = compile(code; lib = false, emit_llvm = true, kws...)
    if isnothing(llvm)
        return
    end
    InteractiveUtils.print_llvm(stdout, read(llvm, String))
    return code
end

function compile_lib(code::Code; kws...)
    return codesnippet(code), compile(code; lib = true, kws...)
end

function compile_and_run(code::Code; verbose = 0, args = String[], valgrind::Bool = false, mpi::Bool = false, num_processes = nothing, show_run_command = !isempty(args) || verbose >= 1, kws...)
    bin_file = compile(code; lib = false, mpi, verbose, kws...)
    if !isnothing(bin_file)
        cmd_vec = [bin_file; args]
        if valgrind
            cmd_vec = ["valgrind"; cmd_vec]
        end
        if mpi
            if !isnothing(num_processes)
                cmd_vec = [["-n", string(num_processes)]; cmd_vec]
            end
            cmd_vec = ["mpiexec"; cmd_vec]
        end
        cmd = Cmd(cmd_vec)
        if show_run_command
            @info("Running : $cmd") # `2:end-1` to remove the backsticks
        end
        try
            run(cmd)
        catch err
            @warn(string(typeof(err)))
        end
    end
    return codesnippet(code)
end

function wrap_in_main(content)
    code = content.code
    if code[end] == '\n'
        code = code[1:end-1]
    end
    return typeof(content)("""
#include <stdlib.h>

int main(int argc, char **argv) {
$(MultilineStrings.indent(code, 2))
}
""")
end

function wrap_compile_and_run(code; kws...)
    compile_and_run(wrap_in_main(code); kws...)
    return code
end

# TODO It would be nice if the user could select a dropdown or hover with the mouse and see the full code
function codesnippet(code::Code)
    lines = readlines(IOBuffer(code.code))
    i = findfirst(line -> contains(line, "codesnippet"), lines)
    if isnothing(i)
        return code
    end
    j = findlast(line -> contains(line, "codesnippet"), lines)
    return typeof(code)(join(lines[i+1:j-1], '\n'))
end

struct Example
    name::String
end

function code(example::Example)
    code = read(joinpath(dirname(dirname(dirname(@__DIR__))), "examples", example.name), String)
    ext = split(example.name, '.')[end]
    if ext == "c"
        return CCode(code)
    elseif ext == "cpp" || ext == "cc"
        return CppCode(code)
    elseif ext == "cl"
        return CLCode(code)
    else
        error("Unrecognized extension `$ext`.")
    end
end

function compile_and_run(example::Example; kws...)
    return compile_and_run(code(example); kws...)
end

function compile_lib(example::Example; kws...)
    return compile_lib(code(example); kws...)
end

# Taken from `JuMP/src/JuMP.jl`
const _EXCLUDE_SYMBOLS = [Symbol(@__MODULE__), :eval, :include]

for sym in names(@__MODULE__; all = true)
    sym_string = string(sym)
    if sym in _EXCLUDE_SYMBOLS ||
       startswith(sym_string, "_") ||
       startswith(sym_string, "@_")
        continue
    end
    if !(
        Base.isidentifier(sym) ||
        (startswith(sym_string, "@") && Base.isidentifier(sym_string[2:end]))
    )
        continue
    end
    @eval export $sym
end

end # module SimpleClang
