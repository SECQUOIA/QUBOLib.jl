const HEN_DATA = Dict(
    "arXiv-1903-10928-3r3x" => Dict(
        :url  => "https://sites.usc.edu/itayhen/files/2019/09/3r3x.zip",
        :data => Dict{String,Any}(
            "name"        => "3-Regular 3-XORSAT (arXiv:1903.10928)",
            "author"      => ["Itay Hen"],
            "description" => "3R3X instances for 'Equation Planting: A Tool for Benchmarking Ising Machines'",
            "year"        => 2019,
            "url"         => "https://arxiv.org/abs/1903.10928",
        ),
    ),
    "arXiv-1903-10928-5r5x" => Dict(
        :url  => "https://sites.usc.edu/itayhen/files/2019/09/5r5x.zip",
        :data => Dict{String,Any}(
            "name"        => "5-Regular 5-XORSAT (arXiv:1903.10928)",
            "author"      => ["Itay Hen"],
            "description" => "5R5X instances for 'Equation Planting: A Tool for Benchmarking Ising Machines'",
            "year"        => 2019,
            "url"         => "https://arxiv.org/abs/1903.10928",
        ),
    ),
    "arXiv-2103-08464-3r3x" => Dict(
        :url  => "https://unmm-my.sharepoint.com/personal/talbash_unm_edu/_layouts/15/download.aspx?SourceUrl=%2Fpersonal%2Ftalbash%5Funm%5Fedu%2FDocuments%2FWebsiteData%2FarXiv210308464%2F3r3x%5F2body%2Ezip",
        :data => Dict{String,Any}(
            "name"        => "3-Regular 3-XORSAT (arXiv:2103.08464)",
            "author"      => ["Matthew Kowalsky", "Tameem Albash", "Itay Hen", "Daniel A. Lidar"],
            "description" => "3R3X instances for '3-Regular 3-XORSAT Planted Solutions Benchmark of Classical and Quantum Heuristic Optimizers'",
            "year"        => 2021,
            "url"         => "https://arxiv.org/abs/2103.08464",
        ),
    ),
)

function load_hen!(index::QUBOLib.LibraryIndex, code::AbstractString)
    @info "[$code] Downloading instances"

    data_path = mkpath(QUBOLib.cache_data_path(index, code))
    file_path = QUBOLib.cache_path(index, code, "$code.zip")

    # Download arXiv_2103_08464 3r3x archive
    if isfile(file_path)
        @info "[$code] Archive already downloaded"
    else
        @info "[$code] Downloading archive"

        Downloads.download(HEN_DATA[code][:url], file_path)
    end

    # Extract arXiv_2103_08464 3r3x archive
    @assert success(`which unzip`) "'unzip' is required to extract QPLIB archive"

    @info "[$code] Extracting archive"

    run(`unzip -qq -o -j $file_path 'instance*.txt' -d $data_path`)

    return nothing
end

function build_hen!(index::QUBOLib.LibraryIndex; cache::Bool = true)
    for code in keys(HEN_DATA)
        build_hen!(index, code; cache)
    end

    return nothing
end

function build_hen!(index::QUBOLib.LibraryIndex, code::AbstractString; cache::Bool = true)
    @info "[$code] Building index"

    if QUBOLib.has_collection(index, code)
        @info "[$code] Collection already exists"

        if cache
            return nothing
        else
            QUBOLib.remove_collection!(index, code)
        end
    end

    load_hen!(index, code)

    QUBOLib.add_collection!(index, code, HEN_DATA[code][:data])

    data_path = QUBOLib.cache_data_path(index, code)

    for path in readdir(data_path; join = true)
        model = try
            QUBOTools.read_model(path, QUBOTools.Qubist())
        catch e
            if e isa QUBOTools.SyntaxError
                @warn """
                [$code] Failed to read instance '$path':
                $(sprint(showerror, e))
                """

                continue
            else
                rethrow(e)
            end
        end

        mod_i = QUBOLib.add_instance!(index, model, code; name = basename(path))

        if isnothing(mod_i)
            @warn "[$code] Failed to read instance '$path'"
        end
    end

    return nothing
end