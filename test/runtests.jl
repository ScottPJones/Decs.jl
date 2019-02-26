using Decs
using Test

const d = [
    Dec(2, -1)
    Dec(2, -1)
    Dec(100, -4)
    Dec(1512, -2)
    Dec(-3, -2)
    Dec(-4, -6)
]

const testdecs =
[
 (Dec(1, -3),    "0.001",   0.001,       Float64),
 (Dec(1523, -2), "15.23",   15.23,       Float64),
 (Dec(543, 0),   "543",     543,         UInt),
 (Dec(-345, 0),  "-345",    -345,        Int),
 (Dec(123, 0),   "123",     123,         Int32),
 (Dec(-32, 0),   "-32",     -32,         Int8),
 (Dec(2001, 2),  "200100",  200100,      BigInt),
 (Dec(123, -2),  "1.23",    1.23,        Float64)
]

@testset "Decs" begin

@testset "Dec constructor" begin

@test isa(d, Vector{Dec})

end

@testset "Conversions" begin

@testset "String/Number to Dec" begin
    # Note: comparison to binary floats, where the value may not be representable exactly
    # may cause problems in the tests
    @testset "Direct" begin
        @test dec"0.01" == Dec(0.01) == Dec(1, -2)
        @test dec".001" == Dec(.001) == Dec(1, -3)
        @test dec"15.23" == Dec(15.23) == Dec(1523, -2)
        @test dec"543" == Dec(543) == Dec(543, 0)
        @test dec"-345" == Dec(-345) == Dec(-345, 0)
        @test dec"000123" == Dec(000123) == Dec(123, 0)
        @test dec"-00032" == Dec(-00032) == Dec(-32, 0)
        @test dec"200100" == Dec(200100) == Dec(2001, 2)
        @test dec"-.123" == Dec(-.123) == Dec(-123, -3)
        @test dec"1.23000" == Dec(1.23000) == Dec(123, -2)
        @test dec"4734.612" == Dec(4734.612) == Dec(4734612, -3)
        @test dec"541724.2" == Dec(541724.2) == Dec(5417242, -1)
        @test dec"2.5e6" == Dec(2.5e6) == Dec(25, 5)
        @test dec"2.385350e8" == Dec(2.385350e8) == Dec(238535, 3)
        @test dec"12.3e-4" == Dec(12.3e-4) == Dec(123, -5)

        @test dec"-12.3e4" == Dec(-12.3e4) == Dec(-123, 3)

        @test dec"-12.3e-4" == Dec(-12.3e-4) == Dec(-123, -5)

        @test dec"0.1234567891" == Dec(0.1234567891) == Dec(1234567891, -10)
        @test dec"0.12345678912" == Dec(0.12345678912) == Dec(12345678912, -11)
    end

    @testset "Using `dec`" begin
        @test dec("1.0") == Dec(1, 0)
        @test dec(8.1) == Dec(81, -1)
        @test dec.(Float64.(d)) == d
    end
end

@testset "Array{<:Number} to Array{Dec}" begin
    @test Dec.([0.1 0.2 0.3]) == [Dec(0.1) Dec(0.2) Dec(0.3)]
end

@testset "Dec to String" begin
    for (d, s, v, T) in testdecs
        @test string(d) == s
        @test T(d) == v
        #@test number(d) == v
    end
    @test string(Float64(Dec(543, 0))) == "543.0"
    #@test string(number(Dec(543, 0)))  == "543"
    #@test string(number(Dec(543, -1))) == "54.3"
end

@testset "Float32" begin
    # Note that 0.01f0 != 0.01
    d = Dec(1, -2)
    @test string(d) == "0.01"
    @test Float32(d) == 0.01f0
    #@test number(d) == 0.01
end

@testset "BigFloat" begin
    d = Dec(-123, -3)
    @test string(d) == "-0.123"
    @test BigFloat(d) == big"-0.123"
    #@test number(d) == -0.123
end

end # constructor

@testset "Normalization" begin

@test Dec(-151100, -4) == Dec(-1511, -2)
@test Dec(100100, -5) == Dec(1001, -3)
#@test normalize(Dec(-151100, -4)) == Dec(-1511, -2)
#@test normalize(Dec(100100, -5)) == Dec(1001, -3)
@test dec"3.0"    == Dec(3, 0)
@test dec"3.0"    == Dec(30, -1)
@test dec"3.1400" == Dec(314, -2)
@test dec"1234"   == Dec(1234, 0)

end # Normalization

@testset "Arithmetic" begin

@testset "Addition" begin
    @test Dec(0.1) + 0.2 == 0.1 + Dec(0.2) == Dec(0.1) + Dec(0.2) == Dec(0.3)
    @test Dec.([0.1 0.2]) .+ [0.3 0.1] == Dec.([0.4 0.3])
    @test Dec(2147483646) + Dec(1) == Dec(2147483647)
    @test Dec(-3, -2) + dec"0.2523410412138103" == Dec(2223410412138103, -16)
end

@testset "Subtraction" begin
    @test Dec(0.3) - 0.1 == 0.3 - Dec(0.1)
    @test 0.3 - Dec(0.1) == Dec(0.3) - Dec(0.1)
    @test Dec(0.3) - Dec(0.1) == Dec(0.2)
    @test Dec.([0.3 0.1]) .- [0.1 0.5] == Dec.([0.2 -0.4])
end

@testset "Negation" begin
    @test -Dec.([0.3 0.2]) == [-Dec(0.3) -Dec(0.2)]
    @test -Dec(0.3) == zero(Dec) - Dec(0.3)
    @test iszero(dec(12.1) - dec(12.1))
end

@testset "Multiplication" begin
    @test Dec(12.21) * Dec(2.12) == Dec(0, -4, 258852)
    @test Dec(12.2112543) * Dec(2.121352) == Dec(0, -13, 259043687318136)
    @test Dec(0.2) * 0.1 == 0.2 * Dec(0.1)
    @test 0.2 * Dec(0.1) == Dec(0.02)
    @test Dec(12.34) * 0.1234 == 12.34 * Dec(0.1234)
    @test 12.34 * Dec(0.1234) == Dec(1.522756)
    @test Dec(0.21084210) * -2 == -2 * Dec(0.21084210)
    @test -2 * Dec(0.21084210) == Dec(-0.4216842)
    @test Dec(0, 2, -1) * 0.0 == zero(Dec)
    @test Dec.([0.3, 0.6]) .* 5 == [Dec(0.3)*5, Dec(0.6)*5]
    @test one(Dec) * 1 == Dec(1, 0)
end

@testset "Inversion" begin
    @test inv(Dec(1, -1))   == Dec(1, 1)
    @test inv(Dec(1, 1))    == Dec(1, -1)
    @test inv(Dec(-2, -1))  == Dec(-5, 0)
    @test inv(Dec(-5, 0))   == Dec(-2, -1)
    @test inv(Dec(2, -2))   == Dec(5, 1)
    @test inv(Dec(5, 1))   == Dec(2, -2)
    @test inv(Dec(-4, -1))  == Dec(-25, -1)
    @test inv(Dec(-25, -1)) == Dec(-4, -1)
end

@testset "Division" begin
    @test Dec(0.2) / Dec(0.1) == Dec(2)
    @test Dec(0.3) / Dec(0.1) == Dec(3, 0)
    @test [Dec(0.3) / Dec(0.1), Dec(0.6) / Dec(0.1)] == [Dec(0.3), Dec(0.6)] ./ Dec(0.1)
    @test [Dec(0.3) / 0.1, Dec(0.6) / 0.1] == [Dec(0.3), Dec(0.6)] ./ 0.1
end

end # Arithmetic

@testset "Equality" begin

@testset "isequal" begin
    @test isequal(Dec(0, -3, 2), Dec(0, -3, 2))
    @test !isequal(Dec(0, -3, 2), Dec(0, 3, 2))
    @test isequal(Dec(0, -3, 2), 0.002)
    @test isequal(Dec(1, 0, 2), -2)
    @test !isequal(Dec(1, 0, 2), 2)
    @test !isequal(Dec(1, -1, 0), Dec(0, 0, 0))
end

@testset "==" begin
    @test Dec(2, -3) == Dec(2, -3)
    @test Dec(2, -3) != Dec(2, 3)
    @test Dec(2, -3) == 0.002

    @test -2 == Dec(-2, 0)
    @test 2 != Dec(-2, 0)

    @test Dec(-2, 0) == -2
    @test Dec(-2, 0) != 2

    bf_pi = BigFloat(pi)
    @test Dec(bf_pi) == bf_pi
    @test bf_pi == Dec(bf_pi)

    bi = big"4608230166434464229556241992703"
    @test Dec(bi) == bi
    @test bi == Dec(bi)

    @test dec(12.1) == dec(12.1)

    # Test negative zero
    @test Dec(1, -1, 0) == Dec(0)
end

@testset "<" begin
    @test Dec(-1, 1)      < Dec(1, 1)
    @test !(Dec(1, 1)     < Dec(-1, 1))
    @test Dec(2, -3)      < Dec(2, 3)
    @test !(Dec(2, 3)     < Dec(2, -3))
    @test !(dec(12.1)     < dec(12.1))

    # Tests with negative zero
    @test Dec(1, 1, 1)    < Dec(1, 1, 0)
    @test !(Dec(1, 1, 0)  < Dec(1, 1, 1))
    @test !(Dec(1, -1, 0) < Dec(0))
    @test !(Dec(0)        < Dec(1, -1, 0))
end

end # comparisons

@testset "Rounding" begin

@test round(Dec(7.123456), digits=0) == Dec(7)
@test round(Dec(7.123456), digits=2) == Dec(7.12)
@test round(Dec(7.123456), digits=3) == Dec(7.123)
@test round(Dec(7.123456), digits=5) == Dec(7.12346)
@test round(Dec(7.123456), digits=6) == Dec(7.123456)

@test round.(Dec.([0.1111, 0.2222, 0.8888]), digits=2) == Dec.([0.11, 0.22, 0.89])

function tet()
    a = dec"1.0000001"
    for i = 1:27
        a *= a
    end
    return a
end

# set DIGITS = 20 (aaljuffali's example)
#@test tet() == Dec(0, -20, 67453047074102193157641340)

end # Rounding
end # Decs
