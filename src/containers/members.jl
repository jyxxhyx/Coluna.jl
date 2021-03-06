abstract type AbstractMembersContainer end

mutable struct MembersVector{I,K,T} <: AbstractMembersContainer
    elements::Dict{I,K} # holds a reference towards the container of elements (sorted by ID) to which we associate records
    records::Dict{I,T} # holds the records associated to elements that are identified by their ID
end

"""
    MembersVector{T}(elems::Dict{I,K})

Construct a `MembersVector` with indices of type `I`, elements of type `K`, and
records of type `T`.

The `MembersVector` maps each index to a tuple of element and record. This 
structure must be use like a `Vector{I,T}`. If the user looks for an index 
that that has an element associated but no record, `MembersVector` returns 
`zeros(T)`.
"""
function MembersVector{T}(elems::Dict{I,K}) where {I,K,T} 
    return MembersVector{I,K,T}(elems, Dict{I,T}())
end

function MembersVector{T}(elems::ElemDict{VC}) where {VC,T}
    return MembersVector{T}(elems.elements)
end

"""
    getelement(vec, i)

Return the element of `vec` with id `i`.
"""
getelement(vec::MembersVector{I}, i::I) where {I,K,T} = vec.elements[i]

getrecords(vec::MembersVector) = vec.records
getelements(vec::MembersVector) = vec.elements
Base.eltype(vec::MembersVector{I,K,T}) where {I,K,T} = T
Base.ndims(vec::MembersVector) = 1

function Base.setindex!(vec::MembersVector{I,K,T}, val, id::I) where {I,K,T}
    vec.records[id] = val
end

function Base.get(vec::MembersVector{I,K,T}, id::I, default) where {I,K,T}
    Base.get(vec.records, id, default)
end

function Base.getindex(vec::MembersVector{I,K,MembersVector{J,L,T}}, id::I) where {I,J,K,L,T<:Number}
    Base.get(vec, id, Nothing)
end

function Base.getindex(vec::MembersVector{I,K,T}, id::I) where {I,K,T<:Number}
    Base.get(vec, id, zero(T))
end

Base.getindex(vec::MembersVector, ::Colon) = vec

function Base.merge(op, vec1::MembersVector{I,K,T}, vec2::MembersVector{I,K,U}) where {I,K,T,U}
    (vec1.elements === vec2.elements) || error("elements are not the same.") # too much restrictive ?
    MembersVector(vec1.elements, Base.merge(op, vec1.records, vec2.records))
end

function Base.reduce(op, vec::MembersVector)
    Base.mapreduce(e -> e[2], op, vec.records)
end

function Base.:(==)(vec1::MembersVector, vec2::MembersVector)
    vec1.records == vec2.records
end

function Base.:(==)(vec1::Dict, vec2::MembersVector)
    vec1 == vec2.records
end

function Base.:(==)(vec1::MembersVector, vec2::Dict)
    vec1.records == vec2
end

function Base.:(!=)(vec1::MembersVector, vec2::MembersVector)
    vec1.records != vec2.records
end

function Base.haskey(vec::MembersVector{I,K,T}, id::I) where {I,K,T}
    Base.haskey(vec.records, id)
end

"""
    filter(function, vec)

Return a copy of `MembersVector` that contains records that are associated to
elements for which the filtering function returns `true`

# Example

Consider a `vec::MembersVector` that associates variables to coefficients.
We want the coefficients of integer variables :
```julia-repl
julia> filter(var -> integer(var), vec)
```
where function `integer(var)` returns true if variable `var` is integer.

# Iterators

If you want to only iterate over a filtered `MembersVector`, we provide a
method that does not return a copy :
```julia
for (id, value) in Iterators.filter(var -> integer(var), vec)
    # body
end
"""
function Base.filter(f::Function, vec::MembersVector{I,K,T}) where {I,K,T}
    r = Base.filter(e -> f(vec.elements[e[1]]) && e[2] != zero(T), vec.records)
    MembersVector(vec.elements, r)
end

function Base.Iterators.filter(f::Function, vec::MembersVector{I,K,T}) where {I,K,T}
    return Base.Iterators.filter(
        e -> f(vec.elements[e[1]]) && e[2] != zero(T), vec.records
    )
end

function Base.keys(vec::MembersVector)
    Base.keys(vec.records)
end

function Base.copy(vec::V) where {V <: MembersVector}
    return V(vec.elements, deepcopy(vec.records))
end

iterate(d::MembersVector) = iterate(d.records)
iterate(d::MembersVector, state) = iterate(d.records, state)
length(d::MembersVector) = length(d.records)
lastindex(d::MembersVector) = lastindex(d.records)

function Base.show(io::IO, vec::MembersVector{I,J,K}) where {I,J <: AbstractVarConstr,K}
    print(io, "[")
    for (id, val) in vec
        print(io, " ", id, " => (", getname(getelement(vec, id)), ", " , val, ")  ")
    end
    print(io, "]")
end

struct MembersMatrix{I,K,J,L,T} <: AbstractMembersContainer
    cols::MembersVector{I,K,MembersVector{J,L,T}}
    rows::MembersVector{J,L,MembersVector{I,K,T}}
end

"""
    MembersMatrix{T}(columns_elems::Dict{I,K}, rows_elems::Dict{J,L})

Construct a matrix that contains records of type `T`. Rows have indices of type
`J` and elements of type `L`, and columns have indices of type `I` and elements
of type `K`.

`MembersMatrix` supports julia set and get operations.
"""
function MembersMatrix{T}(
    col_elems::Dict{I,K}, row_elems::Dict{J,L}
) where {I,K,J,L,T}
    cols = MembersVector{MembersVector{J,L,T}}(col_elems)
    rows = MembersVector{MembersVector{I,K,T}}(row_elems)
    MembersMatrix{I,K,J,L,T}(cols, rows)
end

function MembersMatrix{T}(
    col_elems::ElemDict{VC1}, row_elems::ElemDict{VC2}
) where {VC1,VC2,T}
    return MembersMatrix{T}(col_elems.elements, row_elems.elements)
end

function _getrecordvector!(
    vec::MembersVector{I,K,MembersVector{J,L,T}}, key::I, elems::Dict{J,L}, 
    create = true
) where {I,K,J,L,T}
    if !haskey(vec, key)
        membersvec = MembersVector{T}(elems)
        if create
            vec[key] = membersvec
        end
        return membersvec
    end
    vec[key]
end

function _setcolumn!(
    m::MembersMatrix{I,K,J,L,T}, col_id::I, col::Dict{J,T}
) where {I,K,J,L,T}
    new_col = MembersVector(m.rows.elements, col)
    _setcolumn!(m, col_id, new_col)
end

function _setcolumn!(
    m::MembersMatrix{I,K,J,L,T}, col_id::I, col::MembersVector{J,L,T}
) where {I,K,J,L,T}
    @assert m.rows.elements == col.elements
    m.cols[col_id] = col
    for (row_id, val) in col
        row = _getrecordvector!(m.rows, row_id, m.cols.elements)
        row[col_id] = val
    end
    m
end

function _setrow!(
    m::MembersMatrix{I,K,J,L,T}, row_id::J, row::Dict{I,T}
) where {I,K,J,L,T}
    new_row = MembersVector(m.cols.elements, row)
    _setrow!(m, row_id, new_row)
end

function _setrow!(
    m::MembersMatrix{I,K,J,L,T}, row_id::J, row::MembersVector{I,K,T}
) where {I,K,J,L,T}
    @assert m.cols.elements == row.elements
    m.rows[row_id] = row
    for (col_id, val) in row
        col = _getrecordvector!(m.cols, col_id, m.rows.elements)
        col[row_id] = val
    end
    m
end

function Base.setindex!(m::MembersMatrix, val, row_id, col_id)
    col = _getrecordvector!(m.cols, col_id, m.rows.elements)
    col[row_id] = val
    row = _getrecordvector!(m.rows, row_id, m.cols.elements)
    row[col_id] = val
    m
end

function Base.setindex!(m::MembersMatrix, row, row_id, ::Colon)
    _setrow!(m, row_id, row)
end

function Base.setindex!(m::MembersMatrix, col, ::Colon, col_id)
    _setcolumn!(m, col_id, col)
end

function Base.getindex(
    m::MembersMatrix{I,K,J,L,T}, row_id::J, col_id::I
) where {I,K,J,L,T}
    if length(m.cols) < length(m.rows) # improve ?
        col = m.cols[col_id]
        col === Nothing && return zero(T)
        return col[row_id]
    else
        row = m.rows[row_id]
        row === Nothing && return zero(T)
        return row[col_id]
    end
end

function Base.getindex(
    m::MembersMatrix{I,K,J,L,T}, row_id::J, ::Colon
) where {I,K,J,L,T}
    _getrecordvector!(m.rows, row_id, m.cols.elements, false)
end

function Base.getindex(
    m::MembersMatrix{I,K,J,L,T}, ::Colon, col_id::I
) where {I,K,J,L,T}
    _getrecordvector!(m.cols, col_id, m.rows.elements, false)
end

"""
    columns(membersmatrix)

Return a `MembersVector` that contains the columns.

When the matrix stores the coefficients of a formulation, the method returns
a `MembersVector` that contains `Variable` as elements. For each 
`Variable`, the record is the `MembersVector` that contains the coefficients of
the `Variable` in each `Constraint`.
"""
function columns(m::MembersMatrix)
    return m.cols
end

"""
    rows(membersmatrix)

Return a `MembersVector`that contains the rows.

When the matrix stores the coefficients of a formulation, the method returns
a `MembersVector` that contains `Constraint` as elements. For each 
`Constraint`, the record is the `MembersVector` that contains the coefficients 
of each `Variable` in the `Constraint`.
"""
function rows(m::MembersMatrix)
    return m.rows
end

"""
    is_consistent(vec::MembersVector)

Return `true` if all non-zero records are associated to an element.

    is_consistent(m::MembersMatrix)

Return `true` if all columns and rows are consistent. 

We recommend the use of `is_consistent` only for debugging purposes.
"""
function is_consistent(vec::MembersVector{I,K,T}) where {I,K,T}
    for (id, value) in vec.records
        if value != zero(T) && !haskey(vec.elements, id)
            return false
        end
    end
    return true
end

function is_consistent(m::MembersMatrix)
    for (key, row) in rows(m)
        if !is_consistent(row)
            return false
        end
    end
    for (key, col) in columns(m)
        if !is_consistent(col)
            return false
        end
    end
    return true
end