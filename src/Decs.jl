"""
Decs package

Copyright 2019 Gandalf Software, Inc., Scott P. Jones
Licensed under MIT License, see LICENSE.md
Originally based/inspired by Decimals.jl (by jack@tinybike.net (Jack Peterson), 7/3/2014)
"""
module Decs

macro dec_str(s, flags...) parse(Dec, s) end

# Note: I don't implement the number() function that Decimals had
# (I don't believe it should be part of the API)

import Base: ==, +, -, *, /, <, inv, round

export Dec, dec, @dec_str

const DIGITS = 20

const DFP_MARKER = BigInt(0)

struct Dec <: AbstractFloat
    sgn::Bool   # true = negative
    pow::Int32  # power of 10
    val::BigInt # value
end

Dec(x::Dec) = x
Dec(x::Real) = parse(Dec, string(x))
Dec(x::Integer, scl=0) = Dec(x < 0, scl, abs(x))

# Until I change to use DecFP for speed and to be able to support +-Inf and NaN:
Base.isfinite(x::Dec) = true
Base.isnan(x::Dec) = false

const dectab = Vector{BigInt}(undef, 128)
const rndtab = Vector{BigInt}(undef, 128)

function __init__()
    for p = 1:length(dectab); v = BigInt(10)^p; dectab[p] = v; rndtab[p] = div(v, 2); end
end

# Primitives to help make these functions more generic later on

const IntDec = Union{Integer, Dec}

_getsign(x::Dec) = x.sgn
_getsign(x::Unsigned) = false
_getsign(x::Integer) = x < 0

_getcoeff(x::Dec) = x.val
_getcoeff(x::Integer) = BigInt(abs(x))
_getcoeff(x::BigInt) = x

_getint(x::Dec) = x.val
_getint(x::Integer) = abs(x)

_getscale(x::Dec) = x.pow
_getscale(x::Integer) = 0

_rnd10(d) = d > length(dectab) ? div(BigInt(10)^d, 2) : rndtab[d]
_pow10(d) = d > length(dectab) ? BigInt(10)^d : dectab[d]
_scale(x, d) = _getcoeff(x) * _pow10(d)

_eq(x::IntDec, y::IntDec) = _getint(x) == _getint(y)

_lt(x::IntDec, y::IntDec) = _getint(x) < _getint(y)

# Promotion rules
Base.promote_rule(::Type{Dec}, ::Type{<:Real}) = Dec

# override definitions in Base
Base.promote_rule(::Type{BigFloat}, ::Type{Dec}) = Dec
Base.promote_rule(::Type{BigInt}, ::Type{Dec}) = Dec

# Addition
function +(x::Dec, y::IntDec)
    xscl = _getscale(x)
    yscl = _getscale(y)
    # Quickly deal with zero case, make sure sign is correct in -0.0 + -0.0 case
    iszero(x) && return iszero(y) ? Dec(_getsign(x) & _getsign(y), 0, min(xscl, yscl)) : y
    iszero(y) && return x
    # Make both the same scale
    dscl = xscl - yscl
    if dscl == 0
        xval = _getcoeff(x)
        yval = _getcoeff(y)
    else
        xval, yval = dscl < 0 ? (_getint(x), _scale(y, -dscl)) : (_scale(x, dscl), _getint(y))
        abs(xscl) < abs(yscl) && (xscl = yscl)
    end
    # Simple case where signs are the same
    (xsgn = _getsign(x)) == _getsign(y) && return Dec(xsgn, xscl, xval + yval)
    # Signs are different, we need to subtract, possibly change sign
    (diff = xval - yval) < 0 ? Dec(!xsgn, xscl, -diff) : Dec(xsgn, xscl, diff)
end
+(x::Integer, y::Dec) = y + x

# Negation
-(x::Dec) = Dec(!x.sgn, x.pow, x.val)

# Subtraction
-(x::Dec, y::IntDec)  = x + -y
-(x::Integer, y::Dec) = -x + y

# Multiplication
*(x::Dec, y::IntDec) =
    Dec(xor(_getsign(x), _getsign(y)), _getscale(x) + _getscale(y), _getint(x) * _getint(y))
*(x::Integer, y::Dec) = y * x

# Inversion
function Base.inv(x::Dec)
    str = string(x)
    if str[1] == '-'
        str = str[2:end]
    end
    b = ('.' in str) ? length(split(str, '.')[1]) : 0
    c = round(BigInt(10)^(-x.pow + DIGITS) / x.val)
    q = (x.pow < 0) ? 1 - b - DIGITS : -b - DIGITS
    #normalize(Dec(x.sgn, q, c))
    Dec(x.sgn, q, c)
end

# Division
function /(x::Dec, y::Dec)
    x * inv(y)
end

# TODO exponentiation

@noinline argerr(str) = throw(ArgumentError("cannot parse \"$str\" as Dec"))

function _makedec(sgn, str, begpos, pos)
    #println("_makedec($sgn, \"$str\", $begpos, $pos) => $(pos-begpos) \"", str[begpos:pos-1], '"')
    (pos - begpos < 19
     ? Dec(sgn, 0, parse(Int64, str[begpos:pos-1]))
     : Dec(sgn, 0, parse(BigInt, str[begpos:pos-1])))
end

function _makedec(sgn, str, begpos, frcpos, frcend, scl)
    #println("_makedec($sgn, \"$str\", $begpos, $frcpos, $frcend, $scl) => \"",
    #str[begpos:frcpos-1], '"')
    v = begpos == frcpos ? BigInt(0) : parse(BigInt, str[begpos:frcpos-1])
    frcpos == frcend && return Dec(sgn, scl, v)
    diff = frcend - frcpos - 1
    #println("sgn = $sgn diff = $diff v = $v scl = $scl, \"", str[frcpos+1:frcend-1], '"')
    Dec(sgn, scl - diff, v * _pow10(diff) + parse(BigInt, str[frcpos+1:frcend-1]))
end

# Convert a string to a decimal, e.g. "0.01" -> Dec(0, -2, 1)
function Base.parse(::Type{Dec}, str::AbstractString)
    # start with +, -, 0, 1-9 or .
    (siz = sizeof(str)) == 0 && argerr(str)
    pos = 1
    c = str[pos]
    sgn = false
    if c == '+'
        (pos += 1) > siz && argerr(str)
        c = str[pos]
    elseif c == '-'
        (pos += 1) > siz && argerr(str)
        c = str[pos]
        sgn = true
    end
    # 'e' or 'E' is not allowed before having at least one digit
    (c == 'e' || c == 'E') && argerr(str)
    # may have any number of leading 0s, ignore them
    begpos = pos
    while c == '0'
        (pos += 1) > siz && return Dec(sgn, 0, 0)
        c = str[pos]
    end
    # Look for an immediate '.' (i.e. only fractional part)
    if c == '.'
        # if the string ends here, it must have had at least one leading zero to be well formed
        # "-.", "+." and "." are not valid, "-0.", "+0." and "0." are valid
        if (pos += 1) > siz
            begpos == siz && argerr(str)
            return Dec(sgn, 0, 0)
        end
        begpos = pos
        while (c = str[pos]) == '0'
            (pos += 1) > siz && return Dec(sgn, pos - begpos, 0)
        end
        # Now we can have 'e', 'E', or digits
        (c == 'e' || c == 'E') && return Dec(sgn, parse(Int32, str[pos+1:siz]) - (pos - begpos), 0)
        frcpos = pos
        while isdigit(c)
            # pos == siz && println("sgn = $sgn, zer = $zer str = \"", str[frcpos:siz], '"')
            (pos += 1) > siz && return Dec(sgn, begpos - pos, parse(BigInt, str[frcpos:siz]))
            c = str[pos]
        end
        (c == 'e' || c == 'E') || argerr(str)
        #println("sgn = $sgn v = ", parse(BigInt, str[frcpos:pos-1]), " scl = ",
        #parse(Int32, str[pos+1:siz]) - zer)
        return Dec(sgn, parse(Int32, str[pos+1:siz]) - (pos - begpos),
                   parse(BigInt, str[frcpos:pos-1]))
    end
    begpos = pos
    # We can have 'e', 'E', or digits 1-9 now
    while isdigit(c)
        (pos += 1) > siz && return _makedec(sgn, str, begpos, pos)
        c = str[pos]
    end
    # We can have '.', 'e', 'E' now
    frcpos = pos
    if c == '.'
        (pos += 1) > siz && return _makedec(sgn, str, begpos, pos-1)
        c = str[pos]
        while isdigit(c)
            (pos += 1) > siz && return _makedec(sgn, str, begpos, frcpos, pos, 0)
            c = str[pos]
        end
    end
    frcend = pos
    # We can now have only 'e' or 'E'
    (c == 'e' || c == 'E' || pos < siz) || argerr(str)
    # We can only have '+', '-', or digit(s) now
    c = str[pos += 1]
    (c == '+' || c == '-') && pos < siz && (c = str[pos += 1])
    # Must have at least one digit
    while isdigit(c)
        (pos += 1) > siz &&
            return _makedec(sgn, str, begpos, frcpos, frcend, parse(Int32, str[frcend+1:siz]))
        c = str[pos]
    end
    argerr(str)
end

dec(x::Real) = Dec(x)
dec(str::AbstractString) = parse(Dec, String(str))

const strzeros = repeat('0', 256)

function outzeros(io::IO, cnt::Integer)
    for i = 1:(cnt>>8)
        print(io, strzeros)
    end
    print(io, strzeros[1:(cnt&255)])
end

Base.tostr_sizehint(x::Dec) =
    Base.GMP.MPZ.sizeinbase(x.val, 10) + (x.pow == 0 ? ndigits(x.pow) + 3 : 1)

# Convert a decimal to a string
function Base.print(io::IO, x::Dec)
    x.sgn && print(io, '-')
    scl = x.pow
    if scl < 0
        c = string(x.val)
        len = sizeof(c)
        shift = scl + len
        if shift > 0
            print(io, c[1:shift], '.', c[(shift+1):len])
        elseif shift == 0
            print(io, "0.", c)
        elseif shift > -4
            print(io, "0.") ; outzeros(io, -shift) ; print(io, c)
        else
            print(io, c, 'e', scl)
        end
    else
        print(io, x.val)
        if scl > 2
            print(io, 'e', scl)
        elseif scl == 2
            print(io, "00")
        elseif scl == 1
            print(io, '0')
        end
    end
    # x.sgn ? x.pow == 0 ? print(io, '-', x.val) : print(io, '-', x.val, 'e', x.pow)
end

# Zero/one value
Base.zero(::Type{Dec}) = Dec(0, 0, 0)
Base.one(::Type{Dec})  = Dec(0, 0, 1)

# convert a decimal to any subtype of Real
#Base.convert(::Type{T}, x::Dec) where {T<:Real} =  parse(T, string(x))

(::Type{T})(x::Dec) where {T<:Integer} = parse(T, string(x))
(::Type{T})(x::Dec) where {T<:AbstractFloat} = parse(T, string(x))
(::Type{Rational{T}})(x::Dec) where {T<:Integer} = convert(Rational{T}, x)
(::Type{Rational{BigInt}})(x::Dec) = convert(Rational{BigInt}, x)

# fast case for Rationals
function Base.convert(::Type{T}, x::Dec) where {T<:Rational{<:Signed}}
    scl = _getscale(x)
    val = _getsign(x) ? -x.val : x.val
    scl < 0 ? T(val, _pow10(-scl)) : T(scl == 0 ? val : val * _pow10(scl), 1)
end

@noinline _inexact(T, x) = throw(InexactError(:convert, T, x))

# fast case for Integers
function Base.convert(::Type{T}, x::Dec) where {T<:Signed}
    scl = _getscale(x)
    val = _getsign(x) ? -x.val : x.val
    if scl < 0
        d, r = divrem(val, _pow10(-scl))
        r == 0 || _inexact(T, x)
        T(d)
    else
        T(scl == 0 ? val : val * _pow10(scl))
    end
end

# sign
Base.signbit(x::Dec) = x.sgn

# Equality

Base.iszero(x::Dec) = iszero(x.val)

# equals() now depends on == instead of the other way round.

function ==(x::Dec, y::IntDec)
    # Check if both are zero, regardless of sign
    iszero(x) && return iszero(y)
    iszero(y) && return false
    # Make sure signs are the same
    _getsign(x) == _getsign(y) || return false
    # If scales are the same, don't bother to equalize the scales
    (d = _getscale(x) - _getscale(y)) == 0 && return _eq(x, y)
    # Find out how much we need to multiply by to equalize the scales
    # Note: further optimization would use tables to see if the size (in limbs, or bits) of the two operands
    # could possibly be ==, without even doing the (somewhat expensive) scaling operation.
    d < 0 ? _eq(x, _scale(y, -d)) : _eq(_scale(x, d), y)
end

==(x::Integer, y::Dec) = y == x

function <(x::Dec, y::IntDec)
    # Check for both zeros, regardless of sign
    iszero(x) && return ifelse(iszero(y), false, !_getsign(y))
    iszero(y) && return _getsign(x)
    # Check signs
    xsgn = _getsign(x)
    ysgn = _getsign(y)
    xsgn == ysgn || return xsgn
    # If scales are the same, don't bother to equalize the scales
    (dscl = _getscale(x) - _getscale(y)) == 0 && return xor(_lt(x, y), ysgn)
    # Find out how much we need to multiply by to equalize the scales
    # Note: further optimization would use tables to see if the size (in limbs, or bits) of the two operands
    # are such that one is definitely larger than the other, without even doing the (somewhat expensive) scaling operation.
    xor(dscl < 0 ? _lt(x, _scale(y, -dscl)) : _lt(_scale(x, dscl), y), ysgn)
end

function <(x::Integer, y::Dec)
    # Check for both zeros, regardless of sign
    iszero(x) && return ifelse(iszero(y), false, !_getsign(y))
    iszero(y) && return _getsign(x)
    # Check signs
    xsgn = _getsign(x)
    ysgn = _getsign(y)
    xsgn == ysgn || return xsgn
    # If scales are the same, don't bother to equalize the scales
    xor((dscl = _getscale(y)) == 0 ? _lt(x, y) :
        (dscl < 0 ? _lt(_scale(x, -dscl), y) : _lt(x, _scale(y, dscl))), ysgn)
end

# 12345e-2 rounded to -1, you want 12e1
# 12345e-4 rounded to 0, you want to divrem by _pow10(-scl)
# 12345e-4 rounded to 3, you want to divrem by _pow10(-scl-digits)
# 12345e-4 rounded to >= 4, return x
# Rounding
function Base._round_digits(x::Dec, r::RoundingMode, digits::Integer, base)
    base != 10 && error("base=$base not implemented for type Dec yet")
    (scl = _getscale(x) + digits) >= 0 && return x
    d, r = divrem(_getint(x), _pow10(-scl))
    c = cmp(r, _rnd10(-scl))
    #println("scl = $scl, d = $d, r = $r, c = $c")
    if c != 0
        flg = (c < 0)
    elseif r === RoundNearest
        flg = iseven(d)
    else
        error("Rounding mode $r not implemented for type Dec yet")
    end
    Dec(_getsign(x), -digits, flg ? d : d + 1)
end

end # Decs
