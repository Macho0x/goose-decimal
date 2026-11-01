# goose-decimal

Version 0.1.

A decimal with a 96-bit coefficient and a scale from 0 to 28, the same value [rust_decimal](https://github.com/paupino/rust-decimal) 1.43 stores. The number is the coefficient divided by 10 to the scale. `text` keeps that scale, so `10.0` stays `10.0`. `normalize` strips trailing zeros, so `10.0` becomes `10`. That string is what Hyperliquid puts in a MessagePack map before it hashes an order.

Copyright 2026 Macho0x. Licensed under Apache-2.0, the same license as Goose.

## Check

Install the Goose compiler, then from this directory:

```sh
goose tests/self_check.goose
```

A good run prints `decimal ok`.

```goose
import decimal from "../decimal";

fn main() {
    let d, ok = decimal::parse("10.0");
    print(ok, " ", decimal::text(decimal::normalize(d)));
}
```

## What is absent

Serde, floats, and the transcendental functions are not here. `PORTING.md` lists the arithmetic this package does match.
