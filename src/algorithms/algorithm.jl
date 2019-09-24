"""
    AbstractAlgorithmResult

Stores the computational results after the end of an algorithm execution.
These data can be used to initialize another execution of the same algorithm or in 
setting the transition to another algorithm.
"""
abstract type AbstractAlgorithmResult end

"""
    prepare!(AlgorithmType, formulation, node, strategy_record, parameters)

Prepares the `formulation` in the `node` to be optimized by algorithm `AlgorithmType`.
"""
function prepare! end

"""
    run!(AlgorithmType, formulation, node, strategy_record, parameters)

Runs the algorithm `AlgorithmType` on the `formulation` in a `node` with `parameters`.
"""
function run! end

# Fallbacks
function prepare!(algo::AbstractAlgorithm, formulation, node, strategy_rec, parameters)
    error("prepare! method not implemented for algorithm $T.")
end

function run!(algo::AbstractAlgorithm, formulation, node, strategy_rec, parameters)
    error("run! method not implemented for algorithm $algo.")
end

"""
    apply!(Algorithm, formulation, node)

Applies the algorithm `Algorithm` on the `formulation` in a `node` with 
`parameters`.
"""
function apply!(algo::AbstractAlgorithm, form, node)
    prepare!(form, node)
    TO.@timeit _to string(algo) begin
        TO.@timeit _to "prepare" begin
            prepare!(algo, form, node)
        end
        TO.@timeit _to "run" begin
            record = run!(algo, form, node)
        end
    end
    set_algorithm_result!(node, algo, record)
    return record
end