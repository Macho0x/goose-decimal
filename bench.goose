// Times this package. One untimed batch, then batches until the window
// elapses. The sink keeps the call alive.
// Build with clang on the revision before a change, then again after:
//   goose build -o decimal-bench bench.goose --cc clang
//   ./decimal-bench
// Row names stay fixed. TinyCC (goose bench.goose) is not a timing result.
// ponytail: a fixed window, not a sampled harness. Rows under a microsecond
// move from run to run; lengthen the window before trusting them.

import os;
import decimal;

var a = decimal::zero();
var b = decimal::zero();
var ten = decimal::zero();
var four = decimal::zero();

fn mark(b: u8, ok: bool) -> u64 {
    if !ok { return 0; }
    let v: u64 = b;
    return v + 1;
}

fn time_batch<F>(batch: i64, ms: i64) -> i64, u64 {
    var sink: u64 = 0;
    var k = 0;
    while k < batch {
        sink += F();
        k += 1;
    }
    var n: i64 = 0;
    var dt: i64 = 0;
    let end = clock_ns() + ms * 1000000;
    while true {
        let t0 = clock_ns();
        k = 0;
        while k < batch {
            sink += F();
            k += 1;
        }
        dt += clock_ns() - t0;
        n += batch;
        if clock_ns() >= end { break; }
    }
    return dt / n, sink;
}

fn row<F>(name: u8[:], batch: i64, ms: i64) -> u64 {
    let ns, part = time_batch(batch, ms, F);
    var line: u8[>..] = [];
    format(line, name);
    while line.len < 28 { line.push(' '); }
    format_int(line, ns, 10, 12, ' ');
    format(line, "\n");
    write_stdout(line);
    return part;
}

fn parse_row() -> u64 {
    let d, ok = decimal::parse("123.456");
    if !ok { return 0; }
    return mark((d.w[0] & 255) as! u8, true);
}

fn mul_row() -> u64 {
    let p, ok = decimal::mul(a, b);
    if !ok { return 0; }
    return mark((p.w[0] & 255) as! u8, true);
}

fn div_row() -> u64 {
    let q, ok = decimal::div(ten, four);
    if !ok { return 0; }
    return mark((q.w[0] & 255) as! u8, true);
}

fn norm_row() -> u64 {
    let n = decimal::normalize(a);
    return mark((n.w[0] & 255) as! u8, true);
}

fn text_row() -> u64 {
    let t = decimal::text(a);
    if t.len == 0 { return 0; }
    return mark(t[0], true);
}

fn ready() -> bool {
    let x, xok = decimal::parse("1.5");
    let y, yok = decimal::parse("2");
    let t, tok = decimal::parse("10");
    let f, fok = decimal::parse("4");
    if !xok || !yok || !tok || !fok { return false; }
    a = x;
    b = y;
    ten = t;
    four = f;
    let p, pok = decimal::mul(a, b);
    if !pok || decimal::text(p) != "3.0" { return false; }
    let q, qok = decimal::div(ten, four);
    if !qok || decimal::text(q) != "2.50" { return false; }
    let wide, wok = decimal::parse("10.0");
    return wok && decimal::text(decimal::normalize(wide)) == "10";
}

fn ::main() {
    if !ready() { print("bench FAIL"); exit(1); }
    write_stdout("operation                       ns/call\n");
    var sink: u64 = 0;
    sink += row("parse", 64, 200, parse_row);
    sink += row("mul", 32, 200, mul_row);
    sink += row("div", 16, 200, div_row);
    sink += row("normalize", 32, 200, norm_row);
    sink += row("text", 32, 200, text_row);
    var tail: u8[>..] = [];
    format(tail, "sink ");
    format(tail, sink);
    format(tail, "\n");
    write_stdout(tail);
}
