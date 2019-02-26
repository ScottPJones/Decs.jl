using Decs
using DecFP
using Decimals
using BenchmarkTools

# Test performance of comparing < and == of numbers with the same or different scales,
# same or different signs, conversion to/from string, +, -, *, /

for T in (Dec, Decimal, Dec64, Dec128, Float64, BigFloat)

    for (sgn, num, scl) in ((0, 0, 0), (1, 0, 0), (0, 123456789, -8),
                            (0, 123400000, -5), (0, 123400000, 0),
                            (0, 1234, 0), (0, 1234, 5))

        s = string(sgn == 0 ? "" : "-", num) * (scl == 0 ? "" : string('e', scl))
        println(T, ":\t", s)
        n = parse(T, s)
        print("parse: ")
        @btime parse($T, $s)
        print("string: ")
        @btime string($n)

        for vs in (-5, 0, 5)
            sv = scl + vs
            vv = string(sgn == 0 ? "" : "-", num) * (sv == 0 ? "" : string('e', sv))
            println("value: ", vv)
            vn = parse(T, vv)
            print("==:     ")
            @btime $n == $vn
            print("<:      ")
            @btime $n < $vn
            print("+:      ")
            @btime $n + $vn
            print("*:      ")
            @btime $n * $vn
            if !iszero(vn)
                print("/:      ")
                @btime $n / $vn
            end
        end
    end
end
