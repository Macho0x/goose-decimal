<p align="center">
  <img src="logo.png" alt="A goose holding a coin stamped with a decimal point" width="220">
</p>

<h1 align="center">goose-decimal</h1>

<p align="center">
  A 96-bit decimal for <a href="https://github.com/aardappel/goose">Goose</a><br>
  <strong>0.2.2</strong> · <a href="LICENSE">Apache-2.0</a>
</p>

The same value [rust_decimal](https://github.com/paupino/rust-decimal) 1.43 stores: a 96-bit coefficient and a scale from 0 to 28. The number is the coefficient divided by 10 to that scale.

`text` keeps the scale, so `10.0` stays `10.0`. `normalize` strips trailing zeros, so `10.0` becomes `10`. That string is what you hash when a protocol wants a decimal with no trailing zeros. MessagePack writes the string you give it. It does not do this step.

## Example

```goose
import decimal from "../decimal";

fn main() {
    let d, ok = decimal::parse("10.0");
    if ok {
        print(decimal::text(d));
        print(decimal::text(decimal::normalize(d)));
    }
    let ten, tok = decimal::parse("10");
    let four, fok = decimal::parse("4");
    let q, qok = decimal::div(ten, four);
    if tok && fok && qok { print(decimal::text(q)); }
}
```

`10.0` prints `10.0`, then `10`. `10 / 4` prints `2.50`. Normalizing that gives `2.5`. `0.1 + 0.2` is `0.3`.

## Check

Install the Goose compiler, then from this directory:

```sh
goose tests/self_check.goose
```

A good run prints `decimal ok`.

## What you can call

| Function | What it does |
| --- | --- |
| `parse` | Sign, digits, one dot, and an `e` or `E` exponent. `1e2` is `100`. `1.5e-1` is `0.15` |
| `text` | Keeps the scale |
| `normalize` | Drops factors of 10 while the scale is positive |
| `cmp` | Numeric order. `1.0` and `1.00` compare equal |
| `add`, `sub` | Align to the larger scale. `1.0 - 1.00` is `0.00` |
| `mul` | Multiplies the coefficients and adds the scales. `1.5 * 2` is `3.0` |
| `div` | Grows the quotient the way rust_decimal 1.43 does. `1 / 3` is 28 threes |

A zero divisor, and a coefficient that does not fit in 96 bits, return false. Nothing here aborts. `PORTING.md` names the rust_decimal pieces that are not in this package: serde, floats, and the transcendental functions.

## Benchmarks

`bench.goose` times this package. The row names stay fixed, so a clang run before a change and a clang run after it compare.

```sh
goose build -o decimal-bench bench.goose --cc clang
./decimal-bench
```

`goose bench.goose` runs in TinyCC. That is not a timing result. Numbers depend on the machine, so this page does not publish them.

## License

Apache-2.0. Free and open to everyone. The terms are in [LICENSE](LICENSE).
