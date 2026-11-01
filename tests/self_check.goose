import decimal from "..";
import os;

fn fail(why: u8[:]) {
    write_stdout(why);
    write_stdout("\n");
    exit(1);
}

fn show(s: u8[:]) -> u8[>..] {
    let d, ok = decimal::parse(s);
    if !ok { fail(s); }
    return decimal::text(d);
}

fn norm(s: u8[:]) -> u8[>..] {
    let d, ok = decimal::parse(s);
    if !ok { fail(s); }
    return decimal::text(decimal::normalize(d));
}

fn need(got: u8[:], want: u8[:], why: u8[:]) {
    if got != want { fail(why); }
}

fn ::main() {
    need(show("0"), "0", "0");
    need(show("10"), "10", "10");
    need(show("10.0"), "10.0", "10.0");
    need(show("10.00"), "10.00", "10.00");
    need(show("0.10"), "0.10", "0.10");
    need(show("1.2300"), "1.2300", "1.2300");
    need(show("0.000"), "0.000", "0.000");
    need(show("-10.50"), "-10.50", "-10.50");
    need(show("123.456"), "123.456", "123.456");
    need(show("0.00000001"), "0.00000001", "small");
    need(show("-0.10"), "-0.10", "-0.10");
    need(show("-0.000"), "0.000", "neg zero");
    need(show("1e2"), "100", "1e2");
    need(show("1E2"), "100", "1E2");
    need(show("1.5e-1"), "0.15", "sci");
    need(show("+10"), "10", "plus");
    need(show("10."), "10", "dot");
    need(show(".5"), "0.5", "lead dot");
    need(show("79228162514264337593543950335"), "79228162514264337593543950335", "max");

    need(norm("10.0"), "10", "n 10.0");
    need(norm("0.10"), "0.1", "n 0.10");
    need(norm("1.2300"), "1.23", "n 1.23");
    need(norm("0.000"), "0", "n 0");
    need(norm("-10.50"), "-10.5", "n -10.50");
    need(norm("0.00000001"), "0.00000001", "n small");
    need(norm("-0.10"), "-0.1", "n -0.10");
    need(norm("1.0000000000000000000000000000"), "1", "n ones");

    let a, aok = decimal::parse("0.1");
    let b, bok = decimal::parse("0.2");
    if !aok || !bok { fail("parse add"); }
    let sum, sok = decimal::add(a, b);
    if !sok { fail("add"); }
    need(decimal::text(sum), "0.3", "0.1+0.2");

    let c, cok = decimal::parse("1.5");
    let two, tok = decimal::parse("2");
    if !cok || !tok { fail("parse mul"); }
    let prod, pok = decimal::mul(c, two);
    if !pok { fail("mul"); }
    need(decimal::text(prod), "3.0", "1.5*2");

    let one, ook = decimal::parse("1");
    let eight, eok = decimal::parse("8");
    let three, hok = decimal::parse("3");
    let ten, tnok = decimal::parse("10");
    let four, fok = decimal::parse("4");
    let six, sxok = decimal::parse("6");
    if !ook || !eok || !hok || !tnok || !fok || !sxok { fail("parse div"); }

    let q8, q8ok = decimal::div(one, eight);
    if !q8ok { fail("1/8"); }
    need(decimal::text(q8), "0.125", "1/8 text");

    let q3, q3ok = decimal::div(one, three);
    if !q3ok { fail("1/3"); }
    need(decimal::text(q3), "0.3333333333333333333333333333", "1/3 text");

    let q4, q4ok = decimal::div(ten, four);
    if !q4ok { fail("10/4"); }
    need(decimal::text(q4), "2.50", "10/4 text");
    need(decimal::text(decimal::normalize(q4)), "2.5", "10/4 norm");

    let q6, q6ok = decimal::div(one, six);
    if !q6ok { fail("1/6"); }
    need(decimal::text(q6), "0.1666666666666666666666666667", "1/6 text");

    let top, topok = decimal::parse("2.5");
    let tenth, tenthok = decimal::parse("0.1");
    if !topok || !tenthok { fail("parse 2.5"); }
    let q25, q25ok = decimal::div(top, tenth);
    if !q25ok { fail("2.5/0.1"); }
    need(decimal::text(q25), "25", "2.5/0.1");

    let u, uok = decimal::parse("1.0");
    let v, vok = decimal::parse("1.00");
    if !uok || !vok { fail("parse cmp"); }
    if decimal::cmp(u, v) != 0 { fail("cmp"); }
    let diff, dok = decimal::sub(u, v);
    if !dok { fail("sub"); }
    need(decimal::text(diff), "0.00", "1.0-1.00");

    let z, zok = decimal::div(one, decimal::zero());
    if zok { fail("div0"); }

    let bad, badok = decimal::parse("");
    if badok { fail("empty"); }
    let junk, jok = decimal::parse("12x");
    if jok { fail("junk"); }

    write_stdout("decimal ok\n");
}
