// rust_decimal's decimal: a 96-bit coefficient and a scale from 0 to 28.
// The value is coefficient / 10^scale. w[0] is the least significant limb.
// text keeps the scale, so 10.0 stays "10.0". normalize strips trailing
// zeros, which is the string Hyperliquid hashes. div follows rust_decimal
// 1.43: it grows the quotient by powers of ten, then unscale drops 10^8,
// 10^4, 10^2, and one factor of ten. A zero divisor and a coefficient
// that does not fit return false. Nothing here aborts.

namespace decimal;

const MAX_SCALE: i64 = 28;

const POW10: u32[10] = [
    1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000,
];

struct Dec {
    w: u32[3],
    scale: u32,
    neg: bool,
}

fn zero() -> Dec { Dec { w: [0; 3], scale: 0, neg: false } }

fn mag_zero(a: u32[3]) -> bool {
    return a[0] == 0 && a[1] == 0 && a[2] == 0;
}

fn mag4_zero(a: u32[4]) -> bool {
    return a[0] == 0 && a[1] == 0 && a[2] == 0 && a[3] == 0;
}

fn mag_cmp(a: u32[3], b: u32[3]) -> i64 {
    for i in 0..3 {
        let k = 2 - i;
        if a[k] < b[k] { return -1; }
        if a[k] > b[k] { return 1; }
    }
    return 0;
}

fn mag4_cmp(a: u32[4], b: u32[4]) -> i64 {
    for i in 0..4 {
        let k = 3 - i;
        if a[k] < b[k] { return -1; }
        if a[k] > b[k] { return 1; }
    }
    return 0;
}

fn mag_sub(a: u32[3], b: u32[3]) -> u32[3] {
    var o: u32[3] = [0; 3];
    var borrow: u64 = 0;
    for i in 0..3 {
        let av: u64 = a[i];
        let bv: u64 = b[i];
        let sub = bv + borrow;
        if av >= sub {
            o[i] = (av - sub) as u32;
            borrow = 0;
        } else {
            o[i] = (av + 4294967296 - sub) as u32;
            borrow = 1;
        }
    }
    return o;
}

fn sub4(a: u32[4], b: u32[4]) -> u32[4] {
    var o: u32[4] = [0; 4];
    var borrow: u64 = 0;
    for i in 0..4 {
        let av: u64 = a[i];
        let bv: u64 = b[i];
        let sub = bv + borrow;
        if av >= sub {
            o[i] = (av - sub) as u32;
            borrow = 0;
        } else {
            o[i] = (av + 4294967296 - sub) as u32;
            borrow = 1;
        }
    }
    return o;
}

fn add_u32(a: u32[3], v: u32) -> u32[3], bool {
    var o = a;
    var carry: u64 = v;
    for i in 0..3 {
        let s = (o[i]) + carry;
        o[i] = (s & 0xffffffff) as u32;
        carry = s >> 32;
    }
    return o, carry == 0;
}

fn mul_u32(a: u32[3], m: u32) -> u32[3], u32 {
    var o: u32[3] = [0; 3];
    var carry: u64 = 0;
    for i in 0..3 {
        let ai: u64 = a[i];
        let mm: u64 = m;
        let p = ai * mm + carry;
        o[i] = (p & 0xffffffff) as u32;
        carry = p >> 32;
    }
    return o, carry as u32;
}

fn mul4_u32(a: u32[4], m: u32) -> u32[4], bool {
    var o: u32[4] = [0; 4];
    var carry: u64 = 0;
    for i in 0..4 {
        let ai: u64 = a[i];
        let mm: u64 = m;
        let p = ai * mm + carry;
        o[i] = (p & 0xffffffff) as u32;
        carry = p >> 32;
    }
    return o, carry == 0;
}

fn mul3_to4(d: u32[3], k: u32) -> u32[4] {
    let w, c = mul_u32(d, k);
    return [w[0], w[1], w[2], c];
}

fn div10(a: u32[3]) -> u32[3], u32 {
    var o: u32[3] = [0; 3];
    var rem: u64 = 0;
    let ten: u64 = 10;
    for i in 0..3 {
        let k = 2 - i;
        let cur = (rem << 32) | (a[k]);
        let q = cur / ten;
        o[k] = q as u32;
        rem = cur - q * ten;
    }
    return o, rem as u32;
}

fn div_u32(a: u32[3], m: u32) -> u32[3], u32 {
    var o: u32[3] = [0; 3];
    var rem: u64 = 0;
    let div: u64 = m;
    for i in 0..3 {
        let k = 2 - i;
        let cur = (rem << 32) | (a[k]);
        let q = cur / div;
        o[k] = q as u32;
        rem = cur - q * div;
    }
    return o, rem as u32;
}

fn shl1(r: u32[3], bit: u32) -> u32[3] {
    var o: u32[3] = [0; 3];
    var carry = bit;
    for i in 0..3 {
        let w = r[i];
        o[i] = (w << 1) | carry;
        carry = w >> 31;
    }
    return o;
}

fn divmod(n: u32[3], d: u32[3]) -> u32[3], u32[3] {
    var q: u32[3] = [0; 3];
    var r: u32[3] = [0; 3];
    let one: u32 = 1;
    for step in 0..96 {
        let from_top: i64 = 95 - step;
        let limb = from_top / 32;
        let off = (from_top % 32) as u32;
        let bit = (n[limb] >> off) & 1;
        r = shl1(r, bit);
        if mag_cmp(r, d) >= 0 {
            r = mag_sub(r, d);
            q[limb] = q[limb] | (one << off);
        }
    }
    return q, r;
}

fn scale_up(w: u32[3], by: i64) -> u32[3], bool {
    var a = w;
    for i in 0..by {
        let n, c = mul_u32(a, 10);
        if c != 0 { return a, false; }
        a = n;
    }
    return a, true;
}

fn pow_fits(a: u32[3], p: i64) -> bool {
    if p <= 0 { return true; }
    if p > 9 { return false; }
    let _, c = mul_u32(a, POW10[p]);
    return c == 0;
}

fn find_scale(q: u32[3], scale: i64) -> i64 {
    if scale >= MAX_SCALE { return 0; }
    var room = MAX_SCALE - scale;
    if room > 9 { room = 9; }
    var p = room;
    while p > 0 {
        if pow_fits(q, p) { return p; }
        p -= 1;
    }
    return 0;
}

fn quot_digit(rem: u32[4], d: u32[3]) -> u32 {
    var k: u32 = 0;
    for t in 1..10 {
        let prod = mul3_to4(d, t as u32);
        if mag4_cmp(prod, rem) > 0 { break; }
        k = t as u32;
    }
    return k;
}

fn shl1_4(a: u32[4]) -> u32[4], bool {
    var o: u32[4] = [0; 4];
    var c: u32 = 0;
    for i in 0..4 {
        let w = a[i];
        o[i] = (w << 1) | c;
        c = w >> 31;
    }
    return o, c != 0;
}

fn round_up(rem: u32[4], d: u32[3], q: u32[3]) -> bool {
    let twice, ov = shl1_4(rem);
    if ov { return true; }
    let div: u32[4] = [d[0], d[1], d[2], 0];
    let c = mag4_cmp(twice, div);
    if c > 0 { return true; }
    if c < 0 { return false; }
    return (q[0] & 1) == 1;
}

fn unscale(a: u32[3], scale: i64) -> u32[3], i64 {
    var w = a;
    var s = scale;
    while w[0] == 0 && s >= 8 {
        let n, r = div_u32(w, 100000000);
        if r != 0 { break; }
        w = n;
        s -= 8;
    }
    if (w[0] & 0xF) == 0 && s >= 4 {
        let n, r = div_u32(w, 10000);
        if r == 0 { w = n; s -= 4; }
    }
    if (w[0] & 0x3) == 0 && s >= 2 {
        let n, r = div_u32(w, 100);
        if r == 0 { w = n; s -= 2; }
    }
    if (w[0] & 1) == 0 && s >= 1 {
        let n, r = div_u32(w, 10);
        if r == 0 { w = n; s -= 1; }
    }
    return w, s;
}

fn scale_step(q: u32[3], rem: u32[4], d: u32[3], scale: i64, p: i64) -> u32[3], i64, u32[4], bool {
    var qq = q;
    var rr = rem;
    var s = scale;
    for i in 0..p {
        let nq, c = mul_u32(qq, 10);
        if c != 0 { return qq, s, rr, false; }
        let nr, rok = mul4_u32(rr, 10);
        if !rok { return qq, s, rr, false; }
        let digit = quot_digit(nr, d);
        let prod = mul3_to4(d, digit);
        let nqq, aok = add_u32(nq, digit);
        if !aok { return qq, s, rr, false; }
        qq = nqq;
        rr = sub4(nr, prod);
        s += 1;
    }
    return qq, s, rr, true;
}

fn text(d: Dec) -> u8[>..] {
    var out: u8[>..] = [];
    if mag_zero(d.w) {
        out.push('0');
        if d.scale > 0 {
            out.push('.');
            for i in 0..d.scale { out.push('0'); }
        }
        return out;
    }
    if d.neg { out.push('-'); }
    var digs: u8[40] = [0; 40];
    var n = d.w;
    var nd: i64 = 0;
    while !mag_zero(n) {
        let q, r = div10(n);
        digs[nd] = ('0' + r) as! u8;
        nd += 1;
        n = q;
    }
    let scale = d.scale;
    if scale == 0 {
        for i in 0..nd { out.push(digs[nd - 1 - i]); }
        return out;
    }
    if nd > scale {
        let whole = nd - scale;
        for i in 0..whole { out.push(digs[nd - 1 - i]); }
        out.push('.');
        for i in 0..scale { out.push(digs[scale - 1 - i]); }
        return out;
    }
    out.push('0');
    out.push('.');
    let zeros = scale - nd;
    for i in 0..zeros { out.push('0'); }
    for i in 0..nd { out.push(digs[nd - 1 - i]); }
    return out;
}

fn normalize(d: Dec) -> Dec {
    if mag_zero(d.w) { return zero(); }
    var w = d.w;
    var scale = d.scale;
    while scale > 0 {
        let q, r = div10(w);
        if r != 0 { break; }
        w = q;
        scale -= 1;
    }
    return Dec { w: w, scale: scale, neg: d.neg };
}

fn cmp(a: Dec, b: Dec) -> i64 {
    if mag_zero(a.w) && mag_zero(b.w) { return 0; }
    if a.neg && !b.neg { return -1; }
    if !a.neg && b.neg { return 1; }
    var w1 = a.w;
    var w2 = b.w;
    let s1 = a.scale;
    let s2 = b.scale;
    if s1 > s2 {
        let n, ok = scale_up(w2, s1 - s2);
        if !ok { return if a.neg { -1 } else { 1 }; }
        w2 = n;
    } else if s2 > s1 {
        let n, ok = scale_up(w1, s2 - s1);
        if !ok { return if a.neg { 1 } else { -1 }; }
        w1 = n;
    }
    var c = mag_cmp(w1, w2);
    if a.neg { c = -c; }
    return c;
}

fn add_aligned(a: Dec, b: Dec) -> Dec, bool {
    if mag_zero(a.w) { return b, true; }
    if mag_zero(b.w) { return a, true; }
    var w1 = a.w;
    var w2 = b.w;
    var scale = a.scale;
    let s2 = b.scale;
    if scale > s2 {
        let n, ok = scale_up(w2, scale - s2);
        if !ok { return zero(), false; }
        w2 = n;
    } else if s2 > scale {
        let n, ok = scale_up(w1, s2 - scale);
        if !ok { return zero(), false; }
        w1 = n;
        scale = s2;
    }
    if a.neg == b.neg {
        var o: u32[3] = [0; 3];
        var carry: u64 = 0;
        for i in 0..3 {
            let s = (w1[i]) + (w2[i]) + carry;
            o[i] = (s & 0xffffffff) as u32;
            carry = s >> 32;
        }
        if carry != 0 { return zero(), false; }
        return Dec { w: o, scale: scale, neg: a.neg }, true;
    }
    let ord = mag_cmp(w1, w2);
    if ord == 0 { return Dec { w: [0; 3], scale: scale, neg: false }, true; }
    if ord > 0 {
        return Dec { w: mag_sub(w1, w2), scale: scale, neg: a.neg }, true;
    }
    return Dec { w: mag_sub(w2, w1), scale: scale, neg: b.neg }, true;
}

fn add(a: Dec, b: Dec) -> Dec, bool { return add_aligned(a, b); }

fn sub(a: Dec, b: Dec) -> Dec, bool {
    var flipped = b;
    flipped.neg = !b.neg;
    return add_aligned(a, flipped);
}

fn mul(a: Dec, b: Dec) -> Dec, bool {
    if mag_zero(a.w) || mag_zero(b.w) {
        var scale = a.scale + b.scale;
        if scale > MAX_SCALE as u32 { scale = MAX_SCALE as u32; }
        return Dec { w: [0; 3], scale: scale, neg: false }, true;
    }
    var acc: u32[6] = [0; 6];
    for i in 0..3 {
        var carry: u64 = 0;
        for j in 0..3 {
            let k = i + j;
            let ai: u64 = a.w[i];
            let bj: u64 = b.w[j];
            let ak: u64 = acc[k];
            let p = ai * bj + ak + carry;
            acc[k] = (p & 0xffffffff) as u32;
            carry = p >> 32;
        }
        let k = i + 3;
        let s = (acc[k]) + carry;
        acc[k] = (s & 0xffffffff) as u32;
        if (s >> 32) != 0 && k + 1 < 6 {
            acc[k + 1] = acc[k + 1] + ((s >> 32) as u32);
        }
    }
    var scale: i64 = (a.scale) + (b.scale);
    var sticky = false;
    while scale > MAX_SCALE || acc[3] != 0 || acc[4] != 0 || acc[5] != 0 {
        if scale <= 0 { return zero(), false; }
        var rem: u64 = 0;
        let ten: u64 = 10;
        var next: u32[6] = [0; 6];
        for i in 0..6 {
            let k = 5 - i;
            let cur = (rem << 32) | (acc[k]);
            let q = cur / ten;
            next[k] = q as u32;
            rem = cur - q * ten;
        }
        if rem > 5 || (rem == 5 && (sticky || (next[0] & 1) == 1)) {
            let low, ok = add_u32([next[0], next[1], next[2]], 1);
            if !ok { return zero(), false; }
            next[0] = low[0];
            next[1] = low[1];
            next[2] = low[2];
        }
        if rem != 0 { sticky = true; }
        acc = next;
        scale -= 1;
    }
    return Dec { w: [acc[0], acc[1], acc[2]], scale: scale as u32, neg: a.neg != b.neg }, true;
}

fn div(a: Dec, b: Dec) -> Dec, bool {
    if mag_zero(b.w) { return zero(), false; }
    if mag_zero(a.w) { return zero(), true; }
    let q0, r0 = divmod(a.w, b.w);
    var q = q0;
    var rem: u32[4] = [r0[0], r0[1], r0[2], 0];
    var scale: i64 = (a.scale) - (b.scale);
    var saw = false;
    var spins = 0;
    while spins < 64 {
        spins += 1;
        if mag4_zero(rem) {
            if scale >= 0 { break; }
            var p = -scale;
            if p > 9 { p = 9; }
            let nq, ns, nr, ok = scale_step(q, rem, b.w, scale, p);
            if !ok { return zero(), false; }
            q = nq;
            scale = ns;
            rem = nr;
        } else {
            saw = true;
            if scale >= MAX_SCALE || find_scale(q, scale) == 0 {
                if round_up(rem, b.w, q) {
                    let nq, ok = add_u32(q, 1);
                    if !ok { return zero(), false; }
                    q = nq;
                }
                break;
            }
            let p = find_scale(q, scale);
            let nq, ns, nr, ok = scale_step(q, rem, b.w, scale, p);
            if !ok { return zero(), false; }
            q = nq;
            scale = ns;
            rem = nr;
        }
    }
    if saw {
        let uq, us = unscale(q, scale);
        q = uq;
        scale = us;
    }
    if scale < 0 || scale > MAX_SCALE { return zero(), false; }
    return Dec { w: q, scale: scale as u32, neg: a.neg != b.neg }, true;
}

fn parse(s: u8[:]) -> Dec, bool {
    if s.len == 0 { return zero(), false; }
    var i: i64 = 0;
    var neg = false;
    if s[0] == '+' || s[0] == '-' {
        neg = s[0] == '-';
        i = 1;
        if i >= s.len { return zero(), false; }
    }
    var mant: u32[3] = [0; 3];
    var saw = false;
    var frac: i64 = -1;
    while i < s.len {
        let c = s[i];
        if c == '.' {
            if frac >= 0 { return zero(), false; }
            frac = 0;
            i += 1;
            continue;
        }
        if c == 'e' || c == 'E' { break; }
        if c < '0' || c > '9' { return zero(), false; }
        let grown, cary = mul_u32(mant, 10);
        if cary != 0 { return zero(), false; }
        let added, aok = add_u32(grown, (c - '0'));
        if !aok { return zero(), false; }
        mant = added;
        saw = true;
        i += 1;
        if frac >= 0 { frac += 1; }
    }
    if !saw { return zero(), false; }
    if frac < 0 { frac = 0; }
    var exp: i64 = 0;
    if i < s.len && (s[i] == 'e' || s[i] == 'E') {
        i += 1;
        if i >= s.len { return zero(), false; }
        var eneg = false;
        if s[i] == '+' || s[i] == '-' {
            eneg = s[i] == '-';
            i += 1;
            if i >= s.len { return zero(), false; }
        }
        var ev: i64 = 0;
        var esaw = false;
        while i < s.len {
            let c = s[i];
            if c < '0' || c > '9' { return zero(), false; }
            ev = ev * 10 + ((c - '0'));
            esaw = true;
            i += 1;
        }
        if !esaw { return zero(), false; }
        if eneg { exp = -ev; } else { exp = ev; }
    }
    if i != s.len { return zero(), false; }
    var scale = frac - exp;
    if scale < 0 {
        let grown, ok = scale_up(mant, -scale);
        if !ok { return zero(), false; }
        mant = grown;
        scale = 0;
    }
    while scale > MAX_SCALE {
        let q, r = div10(mant);
        if r >= 5 {
            let n, ok = add_u32(q, 1);
            if !ok { return zero(), false; }
            mant = n;
        } else {
            mant = q;
        }
        scale -= 1;
    }
    if mag_zero(mant) { neg = false; }
    return Dec { w: mant, scale: scale as u32, neg: neg }, true;
}

fn ::main() {
    print("goose tests/self_check.goose");
}
