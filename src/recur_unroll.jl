const ShortTuple = Union{
    Tuple{},
    Tuple{A} where {A},
    Tuple{A, B} where {A, B},
    Tuple{A, B, C} where {A, B, C},
    Tuple{A, B, C, D} where {A, B, C, D},
    Tuple{A, B, C, D, E} where {A, B, C, D, E},
    Tuple{A, B, C, D, E, F} where {A, B, C, D, E, F},
    Tuple{A, B, C, D, E, F, G} where {A, B, C, D, E, F, G},
    Tuple{A, B, C, D, E, F, G, H} where {A, B, C, D, E, F, G, H},
    Tuple{A, B, C, D, E, F, G, H, I} where {A, B, C, D, E, F, G, H, I},
    Tuple{A, B, C, D, E, F, G, H, I, J} where {A, B, C, D, E, F, G, H, I, J},
    Tuple{A, B, C, D, E, F, G, H, I, J, K} where {A, B, C, D, E, F, G, H, I, J, K},
    Tuple{A, B, C, D, E, F, G, H, I, J, K, L} where {A, B, C, D, E, F, G, H, I, J, K, L},
    Tuple{A, B, C, D, E, F, G, H, I, J, K, L, M} where {A, B, C, D, E, F, G, H, I, J, K, L, M},
    Tuple{A, B, C, D, E, F, G, H, I, J, K, L, M, N} where {A, B, C, D, E, F, G, H, I, J, K, L, M, N},
    Tuple{A, B, C, D, E, F, G, H, I, J, K, L, M, N, O} where {A, B, C, D, E, F, G, H, I, J, K, L, M, N, O},
    Tuple{A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P} where {A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P}
}

export fill_tuple
"""
```jldoctest
julia> using Keys

julia> fill_tuple((1, 'a', 1.0), "a")
("a", "a", "a")
```
"""
fill_tuple(t::ShortTuple, value) = ntuple(
    let value = value
        x -> value
    end,
    length(t)
)

reduce_unrolled(reducer, ::Tuple{}) = Base._empty_reduce_error()
reduce_unrolled(reducer, args::ShortTuple) = reduce_unrolled(
    reducer,
    args[1],
    tail(args)
)
reduce_unrolled(reducer, default, args::Tuple{}) = default

export reduce_unrolled
"""
```jldoctest
julia> using Keys

julia> reduce_unrolled(&, (true, false, true))
false
```
"""
reduce_unrolled(reducer, default, args::ShortTuple) =
    reducer(default, reduce_unrolled(reducer, args[1], tail(args)))

export getindex_unrolled
getindex_unrolled(into::Tuple{}, switch::Tuple{}) = ()
getindex_unrolled(into::Tuple{}, switch::ShortTuple) = ()
getindex_unrolled(into::ShortTuple, switch::Tuple{}) = ()
"""
```jldoctest
julia> using Keys

julia> getindex_unrolled((1, "a", 1.0), (true, false, true))
(1, 1.0)
```
"""
function getindex_unrolled(into::ShortTuple, switch::ShortTuple)
    next = getindex_unrolled(tail(into), tail(switch))
    if Bool(switch[1])
        (into[1], next...)
    else
        next
    end
end

export setindex_unrolled
"""
```jldoctest
julia> using Keys

julia> setindex_unrolled(
            (1, "a", 1.0),
            ('a', 1//1),
            (True(), False(), True())
        )
('a', "a", 1//1)
```
"""
setindex_unrolled(::Tuple{}, ::Tuple{}, ::Tuple{}) = ()
setindex_unrolled(::Tuple{}, ::Tuple{}, switch::ShortTuple) = ()
setindex_unrolled(::Tuple{}, new::ShortTuple, ::Tuple{}) = ()
setindex_unrolled(::Tuple{}, new::ShortTuple, switch::ShortTuple) = ()
setindex_unrolled(old::ShortTuple, ::Tuple{}, ::Tuple{}) = old
setindex_unrolled(old::ShortTuple, ::Tuple{}, switch::ShortTuple) = old
setindex_unrolled(old::ShortTuple, new::ShortTuple, ::Tuple{}) = ()
function setindex_unrolled(old::ShortTuple, new::ShortTuple, switch::ShortTuple)
    first_tuple, tail_tuple =
        if Bool(switch[1])
            (new[1], tail(new))
        else
            (old[1], new)
        end
    first_tuple, setindex_unrolled(tail(old), tail_tuple, tail(switch))...
end

export find_unrolled
find_unrolled(t::ShortTuple) = find_unrolled(t, 1)
find_unrolled(t::Tuple{}, n::Integer) = ()

"""
```jldoctest
julia> using Keys

julia> find_unrolled((true, false, true))
(1, 3)
```
"""
function find_unrolled(t::ShortTuple, n::Integer)
    next = find_unrolled(tail(t), n + 1)
    if Bool(t[1])
        (n, next...)
    else
        next
    end
end

export flatten_unrolled
"""
```jldoctest
julia> using Keys

julia> flatten_unrolled(((1, 2.0), ("c", 4//4)))
(1, 2.0, "c", 1//1)
```
"""
flatten_unrolled(x::ShortTuple) = x[1]..., flatten_unrolled(tail(x))...
flatten_unrolled(::Tuple{}) = ()

export product_unrolled
"""
```jldoctest
julia> using Keys

julia> product_unrolled((1, 2.0), ("c", 4//4))
((1, "c"), (2.0, "c"), (1, 1//1), (2.0, 1//1))
```
"""
product_unrolled(x::ShortTuple, y::ShortTuple) = flatten_unrolled(map(
    let x = x
        y1 ->
            map(
                let y1 = y1
                    x1 -> (x1, y1)
                end,
                x
            )
    end,
    y
))

export filter_unrolled
"""
```jldoctest
julia> using Keys

julia> filter_unrolled(identity, (True(), False()))
(True(),)
```
"""
filter_unrolled(f, x::ShortTuple) = getindex_unrolled(x, map(f, x))
