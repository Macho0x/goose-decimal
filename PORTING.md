# Porting

The source is rust_decimal 1.43. The checks in `tests/self_check.goose` are strings that crate prints.

## What matches

`parse` accepts an optional sign, digits, one dot, and an `e` or `E` exponent. `10.` is `10`. `.5` is `0.5`. `1e2` is `100`. `1.5e-1` is `0.15`.

`text` keeps the scale. `normalize` divides the coefficient by 10 while the scale is positive and the coefficient is divisible by 10. A zero becomes scale 0 and positive, so `-0.000` displays as `0.000` and normalizes to `0`.

`cmp` compares the numbers, so `1.0` and `1.00` compare equal. `add` and `sub` align to the larger scale. `1.0 - 1.00` is `0.00`. `0.1 + 0.2` is `0.3`.

`mul` multiplies the coefficients and adds the scales. `1.5 * 2` is `3.0`.

`div` follows the 1.43 remainder loop. It extends the quotient by powers of ten, rounds half to even when the scale cannot grow, then `unscale` removes factors of `10^8`, `10^4`, `10^2`, and one factor of ten. `10 / 4` is `2.50`. `normalize` of that is `2.5`. `1 / 3` is 28 threes. `1 / 6` rounds the last digit to 7. Division by zero returns false.

## Names

`Decimal` is `Dec`. `from_str` is `parse`. `Display` is `text`. `normalize`, `cmp`, `add`, `sub`, `mul`, and `div` keep those names. A failure is the trailing `bool`. Zero is `zero`.

## Check

`goose tests/self_check.goose` from this directory printed `decimal ok` with no warnings. The strings in that file are what rust_decimal 1.43 prints for the same inputs.

## What is absent

There is no serde, no `from_f64`, and no `ln`, `exp`, `sin`, or `sqrt`. A coefficient that does not fit in 96 bits returns false. rust_decimal's `+` panics on overflow. This package returns false there instead.
