# QUBOInstances.jl
QUBO Instances for benchmarking

## Introduction

This package provides a wrapper around [QUBOInstancesData.jl](https://github.com/pedromxavier/QUBOInstancesData.jl)'s artifact to easily access QUBO / Ising instances.
Instances are retrieved as model objects from [QUBOTools.jl](https://github.com/psrenergy/QUBOTools.jl).

## Getting Started

### Installation

```julia
julia> import Pkg; Pkg.add(url="https://github.com/pedromxavier/QUBOInstances.jl")

julia> using QUBOInstances
```

### Example

```julia
julia> coll = first(list_collections())   # get code of the first registered collection

julia> inst = first(list_instances(coll)) # get code of the first instance from that collection

julia> model = load_instance(coll, inst)  # retrieve QUBOTools model
```

## Accessing the instance index database

> **Warning**
> This requires [SQLite.jl](https://github.com/JuliaDatabases/SQLite.jl) and [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl) to be installed.


```julia
julia> using SQLite, DataFrames

julia> db = QUBOInstances.database()

julia> df = DBInterface.execute(
           db,
           "SELECT collection, code FROM instances WHERE size BETWEEN 100 AND 200;"
       ) |> DataFrame

julia> models = [
           load_instance(coll, inst)
           for (coll, inst) in zip(df[!, :collection], df[!, :code])
       ]
```
