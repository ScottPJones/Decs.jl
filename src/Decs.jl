"""
Decs package

Copyright 2019 Gandalf Software, Inc., Scott P. Jones
Licensed under MIT License, see LICENSE.md
Originally based/inspired by Decimals.jl (by jack@tinybike.net (Jack Peterson), 7/3/2014)
"""
module Decs

macro dec_str(s, flags...) parse(Dec, s) end

import Base: ==, +, -, *, /, <, float, inv, round

export Dec, dec, @dec_str, number, normalize

const DIGITS = 20

const DFP_MARKER = BigInt(0)

struct Dec <: AbstractFloat
    sgn::Bool   # true = negative
    pow::Int32  # power of 10
    val::BigInt # value
end

Dec(val::Integer, scl) = Dec(val < 0, scl, abs(val))

const dectab = Vector{BigInt}(undef, 38)

function __init__()
    for p = 1:38; dectab[p] = BigInt(10)^p; end
end

# Primitives to help make these functions more generic later on

const IntDec = Union{Integer, Dec}

_getsign(x::Dec) = x.sgn
_getsign(x::Unsigned) = false
_getsign(x::Integer) = x < 0

_getcoeff(x::Dec) = x.val
_getcoeff(x::Integer) = BigInt(abs(x))

_getint(x::Dec) = x.val
_getint(x::Integer) = abs(x)

_getscale(x::Dec) = x.pow
_getscale(x::Integer) = 0

_scale(x, d) = _getcoeff(x) * (d > length(dectab) ? BigInt(10)^d : dectab[d])

_eq(x::IntDec, y::IntDec) = _getint(x) == _getint(y)

_lt(x::IntDec, y::IntDec) = _getint(x) < _getint(y)

# Promotion rules
Base.promote_rule(::Type{Dec}, ::Type{<:Real}) = Dec

# override definitions in Base
Base.promote_rule(::Type{BigFloat}, ::Type{Dec}) = Dec
Base.promote_rule(::Type{BigInt}, ::Type{Dec}) = Dec

# Addition
function +(x::Dec, y::IntDec)
    # Quickly deal with zero case, so as not to worry about -0.0 cases
    iszero(x) && return y
    iszero(y) && return x
    # Make both the same scale
    xscl = _getscale(x)
    yscl = _getscale(y)
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
    normalize(Dec(x.sgn, q, c))
end

# Division
/(x::Dec, y::Dec) = x * inv(y)

# TODO exponentiation

# Convert a string to a decimal, e.g. "0.01" -> Dec(0, -2, 1)
function Base.parse(::Type{Dec}, str::AbstractString)
    'e' in str && return parse(Dec, scinote(str))
    c, q = parameters(('.' in str) ? split(str, '.') : str)
    Dec((str[1] == '-') ? 1 : 0, q, c)
end

dec(str::AbstractString) = parse(Dec, str)

# Convert a number to a decimal
Dec(num::Real) = parse(Dec, string(num))
Base.convert(::Type{Dec}, num::Real) = Dec(num::Real)
dec(x::Real) = Dec(x)
Dec(x::Dec) = x

# Get Dec constructor parameters from string
parameters(x::AbstractString) = (abs(parse(BigInt, x)), 0)

# Get Dec constructor parameters from array
function parameters(x::Array)
    c = parse(BigInt, join(x))
    (abs(c), -length(x[2]))
end

const strzeros = repeat('0', 256)

function outzeros(io::IO, cnt::Integer)
    for i = 1:(cnt>>8)
        print(io, strzeros)
    end
    print(io, strzeros[1:(cnt&255)])
end

# Get decimal() argument from scientific notation
function scinote(str::AbstractString)
    s = (str[1] == '-') ? "-" : ""
    n, expo = split(str, 'e')
    n = split(n, '.')
    if s == "-"
        n[1] = n[1][2:end]
    end
    if parse(Int64, expo) > 0
        shift = parse(Int64, expo) - ((length(n) == 2) ? length(n[2]) : 0)
        s * join(n) * repeat("0", shift)
    else
        shift = -parse(Int64, expo) - ((length(n) == 2) ? length(n[1]) : length(n))
        s * "0." * repeat("0", shift) * join(n)
    end
end

# Convert a decimal to a string
function Base.print(io::IO, x::Dec)
    x.sgn && print(io, '-')
    if x.pow < 0
        c = string(x.val)
        shift = x.pow + length(c)
        if shift > 0
            print(io, c[1:shift], '.', c[(shift+1):end])
        else
            print(io, "0.")
            outzeros(io, -shift)
            print(io, c)
        end
    else
        print(io, x.val)
        x.pow > 0 && outzeros(io, x.pow)
    end
end

# Zero/one value
Base.zero(::Type{Dec}) = Dec(0, 0, 0)
Base.one(::Type{Dec})  = Dec(0, 0, 1)

# convert a decimal to any subtype of Real
(::Type{T})(x::Dec) where {T<:Real} = parse(T, string(x))

# Convert a decimal to an integer if possible, a float if not
function number(x::Dec)
    ix = (str = string(x) ; fx = parse(Float64, str); round(Int64, fx))
    (ix == fx) ? ix : fx
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

# Rounding
function round(x::Dec; digits::Int=0, normal::Bool=false)
    shift = BigInt(digits) + x.pow
    if !(shift > BigInt(0) || shift < x.pow)
        c = Base.round(x.val / BigInt(10)^(-shift))
        x = Dec(x.sgn, x.pow - shift, BigInt(c))
    end
    normal ? x : normalize(x, rounded=true)
end

# Normalization: remove trailing zeros in coefficient
function normalize(x::Dec; rounded::Bool=false)
    # Note: this is very inefficient
    # First, one can count the trailing zero bits, and that will give an indication
    # of the maximum 0 digits (because 10 is 5*2)
    p = 0
    if x.val != 0
        while x.val % BigInt(10)^(p+1) == 0
            p += 1
        end
    end
    c, r = divrem(x.val, BigInt(10)^p)
    q = (c == 0 && !x.sgn) ? 0 : x.pow + p
    v = Dec(x.sgn, q, abs(c))
    rounded ? v : round(v, digits=DIGITS, normal=true)
end

end # Decs
