def get_exponent(num)
    return 0 if num == 0
    exp = Math.log10(num.abs).floor
    num.negative? ? exp - 1 : exp
end