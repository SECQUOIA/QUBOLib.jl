include("index/database.jl")
include("index/archive.jl")

@doc raw"""
    LibraryIndex

The QUBOLib index is composed of two parts: a SQLite database and an HDF5 archive.
"""
struct LibraryIndex
    db::SQLite.DB
    h5::HDF5.File
end

function database(index::LibraryIndex)
    @assert isopen(index)

    return index.db
end

function archive(index::LibraryIndex)
    @assert isopen(index)

    return index.h5
end

function Base.isopen(index::LibraryIndex)
    return isopen(index.db) && isopen(index.h5)
end

function Base.close(index::LibraryIndex)
    close(index.db)
    close(index.h5)

    return nothing
end

function _create_index(path::AbstractString)
    db = _create_database(database_path(path))
    h5 = _create_archive(archive_path(path))

    return LibraryIndex(db, h5)
end

@doc raw"""
    load_index(path::AbstractString)

Loads the library index from the given path.
"""
function load_index(path::AbstractString; create::Bool=false)
    db = _load_database(database_path(path))
    h5 = _load_archive(archive_path(path))

    if isnothing(db) || isnothing(h5)
        if create
            @info "Creating index at '$path'"

            return _create_index(path)
        else 
            error("Failed to load index from '$path'")

            return nothing
        end
    end

    return LibraryIndex(db, h5)
end

function load_index(callback::Function, path::AbstractString=qubolib_path(); create::Bool=false)
    index = load_index(path; create)

    @assert isopen(index)

    try
        return callback(index)
    catch e
        @error("Error during index access: $(sprint(showerror, e)))")

        return nothing
    finally
        close(index)
    end
end

include("index/collections.jl")
include("index/instances.jl")
include("index/solvers.jl")
include("index/solutions.jl")