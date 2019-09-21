using OMEinsum, MISAlgorithms, BitBasis
using MISAlgorithms: get_outer, get_inner, get_inner_and_batch, get_batch, chasing_game
using Test
using Random

function naive_chase(a::Vector{T}, b::Vector{T}) where T
    res = Tuple{Int,Int}[]
    for ia in 1:length(a), ib in 1:length(b)
        a[ia] == b[ib] && push!(res, (ia, ib))
    end
    return res
end

@testset "chasing gate 2 tensors" begin
    cg = chasing_game(([1,2,3], [2,3,4]))
    @test cg == [(2,1), (3,2)]
    cg = chasing_game(([1,2,2,3], [3,4]))
    @test cg == [(4,1)]
    cg = chasing_game(([1,2,2,3], [3,3,4]))
    @test cg == [(4,1), (4,2)]
    cg = chasing_game(([1,2,2,3,3], [3,3,4]))
    @test cg == [(4,1), (4,2), (5,1), (5,2)]
    @test cg == naive_chase([1,2,2,3,3], [3,3,4])
end

@testset "get inner, outer" begin
    # indices are "iiiooobbb"
    @test get_inner(Val(2), bit"0001111") === bit"00"
    @test get_inner_and_batch(Val(2), Val(1), bit"0001111") === bit"000"
    @test get_batch(Val(2), Val(1), bit"0001111") === bit"0"
    @test get_outer(Val(2), Val(0), bit"0001111") === bit"01111"
    @test get_outer(Val(2), Val(0), bit"0001111", bit"001") === bit"101111"
    @test get_outer(Val(2), Val(1), bit"0001111", bit"000") === bit"01111"
end

@testset "sparse contract" begin
    Random.seed!(2)
    ta = bstrand(4, 0.5)
    tb = bstrand(4, 0.5)
    TA, TB = Array(ta), Array(tb)
    @test sum(sparse_contract(Val(2), Val(0), ta, tb)) ≈ sum(ein"lkji,nmji->lknm"(TA, TB))
    @test Array(sparse_contract(Val(2), Val(0), ta, tb)) ≈ ein"lkji,nmji->lknm"(TA, TB)

    # batched
    ta = bstrand(5, 0.5)
    tb = bstrand(5, 0.5)
    TA, TB = Array(ta), Array(tb)
    @test sum(Array(sparse_contract(Val(2), Val(1), ta, tb))) ≈ sum(ein"lkbji,nmbji->lknmb"(TA, TB))
    @test Array(sparse_contract(Val(2), Val(1), ta, tb)) ≈ ein"lkbji,nmbji->lknmb"(TA, TB)
end

@testset "einsum" begin
    Random.seed!(2)

    perms = MISAlgorithms.analyse_batched_perm(('b','j','c','a','e'), ('k','d','c','a','e'), ('b','j','k','d','c'))
    @test perms == ([1, 2, 3, 4, 5], [1, 2, 3, 4, 5], (1, 2, 3, 4, 5), 2, 1)

    sv = SparseVector([1.0,0,0,1,1,0,0,0])
    t1 = bst(sv)
    t2 = bst(sv)
    T1 = Array(t1)
    T2 = Array(t2)
    @test ein"ijk,jkl->il"(t1,t2) ≈ ein"ijk,jkl->il"(T1,T2)

    ta = bstrand(2, 0.5)
    tb = bstrand(2, 0.5)
    TA, TB = Array(ta), Array(tb)
    @test ein"ij,jk->ik"(ta,tb) ≈ ein"ij,jk->ik"(TA,TB)
    @test ta == TA
    @test tb == TB

    ta = bstrand(7, 0.5)
    tb = bstrand(6, 0.5)
    TA, TB = Array(ta), Array(tb)
    code = ein"ijklmbc,ijbxcy->bcmlxky"
    @test OMEinsum.match_rule(code) == OMEinsum.BatchedContract()
    @test Array(code(ta, tb)) ≈ code(TA, TB)
end