# Define codec for QPLIB format
# TODO: Make it available @ QUBOTools

struct Format{F} <: QUBOTools.AbstractFormat
    Format(F::Symbol) = new{F}()
end

function _read_qplib_model(path::AbstractString)
    return open(path, "r") do io
        _read_qplib_model(io)
    end
end

function _read_qplib_line(io::IO)
    line = readline(io)

    # Remove comments and strip line
    return strip(only(match(r"([^#]+)", line)))
end

function _read_qplib_float(io::IO, ∞::AbstractString)
    line = _read_qplib_line(io)

    if line == ∞
        return Inf
    else
        return parse(Float64, line)
    end
end

function QUBOTools.read_model(io::IO, ::Format{:qplib})
    # Read the header
    code = _read_qplib_line(io)

    @assert !isnothing(match(r"(QBB)", _read_qplib_line(io)))

    sense = _read_qplib_line(io)

    @assert sense ∈ ("minimize", "maximize")

    # number of variables
    nv = let
        line = _read_qplib_line(io)
        m    = match(r"([0-9]+)", line)

        if isnothing(m)
            QUBOTools.syntax_error("Invalid number of variables: $(line)")

            return nothing
        end

        parse(Int, m[1])
    end

    V = Set{Int}(1:nv)
    L = Dict{Int,Float64}()
    Q = Dict{Tuple{Int,Int},Float64}()

    # number of quadratic terms in objective
    nq = let
        line = _read_qplib_line(io)
        m    = match(r"([0-9]+)", line)

        if isnothing(m)
            QUBOTools.syntax_error("Invalid number of quadratic terms: $(line)")

            return nothing
        end

        parse(Int, m[1])
    end

    sizehint!(Q, nq)

    for _ = 1:nq
        let
            line = _read_qplib_line(io)
            m    = match(r"([0-9]+)\s+([0-9]+)\s+(\S+)", line)

            if isnothing(m)
                QUBOTools.syntax_error("Invalid quadratic term: $(line)")

                return nothing
            end

            i = parse(Int, m[1])
            j = parse(Int, m[2])
            c = parse(Float64, m[3])

            Q[(i, j)] = c
        end
    end

    # default value for linear coefficients in objective
    dl = parse(Float64, _read_qplib_line(io))

    # number of non-default linear coefficients in objective
    ln = parse(Int, _read_qplib_line(io))

    sizehint!(L, ln)

    if !iszero(dl)
        for i = 1:nv
            L[i] = dl
        end
    end

    for _ = 1:ln
        let line = _read_qplib_line(io)
            m    = match(r"([0-9]+)\s+(\S+)", line)

            if isnothing(m)
                QUBOTools.syntax_error("Invalid linear coefficient: $(line)")

                return nothing
            end

            i = parse(Int, m[1])
            c = parse(Float64, m[2])

            L[i] = c
        end
    end

    β = parse(Float64, _read_qplib_line(io)) # objective constant

    inf = _read_qplib_line(io) # value for infinity

    @assert _read_qplib_float(io, inf) isa Float64 # default variable primal value in starting point
    @assert iszero(parse(Int, _read_qplib_line(io))) # number of non-default variable primal values in starting point

    @assert _read_qplib_float(io, inf) isa Float64 # default variable bound dual value in starting point
    @assert iszero(parse(Int, _read_qplib_line(io))) # number of non-default variable bound dual values in starting point

    @assert iszero(parse(Int, _read_qplib_line(io))) # number of non-default variable names
    @assert iszero(parse(Int, _read_qplib_line(io))) # number of non-default constraint names

    return QUBOTools.Model{Int,Float64,Int}(
        V, L, Q;
        offset      = β,
        domain      = :bool,
        sense       = (sense == "minimize") ? :min : :max,
        description = "QPLib instance no. $code",
    )
end

function _read_qplib_solution(
    path::AbstractString,
    model::QUBOTools.Model{Int,Float64,Int},
    var_map::Dict{Int,Int},
)
    return open(path, "r") do io
        _read_qplib_solution!(io, model, var_map)
    end
end

function _read_qplib_solution!(
    io::IO,
    model::QUBOTools.Model{Int,Float64,Int},
    var_map::Dict{Int,Int},
)
    # Read the header
    λ = let
        m = match(r"objvar\s+([\S]+)", readline(io))

        if isnothing(m)
            QUBOTools.syntax_error("Invalid header")
        end

        tryparse(Float64, m[1])
    end

    if isnothing(λ)
        QUBOTools.syntax_error("Invalid objective value")
    end

    n = QUBOTools.dimension(model)
    ψ = zeros(Int, n)

    for line in eachline(io)
        i, x = let
            m = match(r"b([0-9]+)\s+([\S]+)", line)

            if isnothing(m)
                QUBOTools.syntax_error("Invalid solution input")
            end

            (tryparse(Int, m[1]), tryparse(Float64, m[2]))
        end

        if isnothing(i) || isnothing(x)
            QUBOTools.syntax_error("Invalid variable assignment")
        end

        ψ[var_map[i]] = ifelse(x > 0, 1, 0)
    end

    s = QUBOTools.Sample{Float64,Int}[QUBOTools.Sample{Float64,Int}(ψ, λ)]

    return QUBOTools.SampleSet{Float64,Int}(
        s;
        sense  = QUBOTools.sense(model),
        domain = :bool,
    )
end

function _is_qplib_qubo(path::AbstractString)
    @assert isfile(path) && endswith(path, ".qplib")

    return open(path, "r") do io
        ____ = readline(io)
        type = readline(io)

        return (type == "QBB")
    end
end

function _get_qplib_var_map(path::AbstractString, n::Integer = 1)
    @assert isfile(path) && endswith(path, ".lp")

    var_set = sizehint!(Set{Int}(), n)

    open(path, "r") do io
        for line in eachline(io)
            for m in eachmatch(r"b([0-9]+)", line)
                if !isnothing(m)
                    push!(var_set, parse(Int, m[1]))
                end
            end
        end
    end

    return Dict{Int,Int}(v => i for (i, v) in enumerate(sort!(collect(var_set))))
end

const QPLIB_URL = "https://github.com/JuliaQUBO/QUBOLib.jl/releases/download/data-mirror/qplib.zip"

function build_qplib!(index::QUBOLib.LibraryIndex; cache::Bool = true)
    if QUBOLib.has_collection(index, "qplib")
        @info "[qplib] Collection already exists"

        if cache
            return nothing
        else
            QUBOLib.remove_collection!(index, "qplib")
        end
    end

    @info "[qplib] Building QPLIB"

    QUBOLib.add_collection!(
        index,
        "qplib",
        Dict{String,Any}(
            "name"        => "QPLIB",
            "author"      => [
                "Fabio Furini",
                "Emiliano Traversi",
                "Pietro Belotti",
                "Antonio Frangioni",
                "Ambros Gleixner",
                "Nick Gould",
                "Leo Liberti",
                "Andrea Lodi",
                "Ruth Misener",
                "Hans Mittelmann",
                "Nikolaos Sahinidis",
                "Stefan Vigerske",
                "Angelika Wiegele"
            ],
            "description" => "The Quadratic Programming Library",
            "year"        => 2014,
            "url"         => "http://qplib.zib.de/",
        ),
    )

    code_list = load_qplib!(index)

    @info "[qplib] Building index"

    data_path = QUBOLib.cache_data_path(index, "qplib")

    for code in code_list
        mod_path = joinpath(data_path, "$(code).qplib")
        var_path = joinpath(data_path, "$(code).lp")
        sol_path = joinpath(data_path, "$(code).sol")

        model = QUBOTools.read_model(mod_path, Format(:qplib))
        mod_i = QUBOLib.add_instance!(index, model, "qplib"; name = basename(mod_path))

        if isfile(sol_path)
            var_map = _get_qplib_var_map(var_path)

            sol = _read_qplib_solution(sol_path, model, var_map)

            if !isnothing(sol)
                QUBOLib.add_solution!(index, mod_i, sol)
            else
                @warn "[qplib] Failed to read solution for instance '$code'"
            end
        end
    end

    return nothing
end

function load_qplib!(index::QUBOLib.LibraryIndex)
    @assert Sys.isunix() "Processing QPLIB is only possible on Unix systems"

    data_path = mkpath(QUBOLib.cache_data_path(index, "qplib"))
    file_path = abspath(QUBOLib.cache_path(index, "qplib"), "qplib.zip")

    # Download QPLIB archive
    if isfile(file_path)
        @info "[qplib] Archive already downloaded"
    else
        @info "[qplib] Downloading archive"

        Downloads.download(QPLIB_URL, file_path)
    end

    # Extract QPLIB archive
    @assert run(`which unzip`, devnull, devnull).exitcode == 0 "'unzip' is required to extract QPLIB archive"

    @info "[qplib] Extracting archive"

    run(`unzip -qq -o -j $file_path -d $data_path`)

    # When getting from original source:
    # run(```
    # unzip -qq -o -j 
    #     $file_path
    #     'qplib/html/qplib/*'
    #     'qplib/html/sol/*'
    #     'qplib/html/lp/*'
    #     -d $data_path
    # ```)

    # Remove non-QUBO instances
    @info "[qplib] Removing non-QUBO instances"

    code_list = String[]

    for model_path in filter(endswith(".qplib"), readdir(data_path; join = true))
        code = readline(model_path)

        if !_is_qplib_qubo(model_path)
            rm(joinpath(data_path, "$(code).qplib"); force = true)
            rm(joinpath(data_path, "$(code).lp"); force = true)
            rm(joinpath(data_path, "$(code).sol"); force = true)
        else
            push!(code_list, code)
        end
    end

    return code_list
end

function deploy_qplib!(index::QUBOLib.LibraryIndex)
    close(index)

    src_path = QUBOLib.cache_data_path(index, "qplib")
    dst_path = mkpath(joinpath(QUBOLib.build_path(index), "mirror"))
    zip_path = joinpath(dst_path, "qplib.zip")

    run(`zip -q -j -r $zip_path $src_path`)

    return nothing
end
