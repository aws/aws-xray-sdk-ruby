def get_exponent(num)
    return 0 if num == 0
    exp = Math.log10(num.abs).floor
    num.negative? ? exp - 1 : exp
end

# X-Ray SDK expects time in seconds with nanosecond precision.
def convert_time_in_seconds(time_float)
    exponent = get_exponent(time_float)
    division_factor = 10 ** (exponent - 9)
    time_float / division_factor
end