import Array "mo:base-0.7.3/Array";
import Buffer "mo:base-0.7.3/Buffer";
import Binary "mo:encoding/Binary";
import Iter "mo:base-0.7.3/Iter";
import Nat32 "mo:base-0.7.3/Nat32";
import Nat64 "mo:base-0.7.3/Nat64";

import Hash "../Hash";
import Util "../Utilities";

/// For internal use only.
module {
    // First thirty-two bits of the fractional parts of the cube roots of the 
    // first sixty-four prime numbers.
    private let K : [Nat32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
        0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
        0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
        0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
        0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
        0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    public class SHA2(
        initialState : [Nat32],
        hashSize     : Nat,
    ) : Hash.Hash = {
        private var h   : [var Nat32] = Array.thaw<Nat32>(initialState);
        private var x   : [var Nat8]  = Array.init<Nat8>(64, 0);
        private var nx  : Nat         = 0;
        private var len : Nat64       = 0;

        public func blockSize() : Nat { 64; };

        public func reset() : () {
            h   := Array.thaw<Nat32>(initialState);
            x   := Array.init<Nat8>(64, 0);
            nx  := 0;
            len := 0;
        };

        public func size() : Nat { hashSize; };

        public func sum(bs : [Nat8]) : [Nat8] {
            let cs = checkSum();
            let size = bs.size();
            Array.tabulate<Nat8>(
                size + cs.size(),
                func (x : Nat) {
                    if (x < size) return bs[x];
                    cs[x - size];
                }
            );
        };

        public func checkSum() : [Nat8] {
            let n = len;
            let r = Nat64.toNat(n) % 64;
            var tmp = Array.init<Nat8>(if (r < 56) { 56 - r } else { 64 + 56 - r }, 0);
            tmp[0] := 0x80;
            write(Array.freeze(tmp));
            write(Binary.BigEndian.fromNat64(n << 3));
            assert(nx == 0);
            let digest = Buffer.Buffer<Nat8>(32);
            label l for (i in h.keys()) {
                if (i == 7 and hashSize == 28) { break l; };
                let n = Binary.BigEndian.fromNat32(h[i]);
                for (v in n.vals()) {
                    digest.add(v);
                };
            };
            Buffer.toArray(digest);
        };

        public func write(bs : [Nat8]) : () {
            var p = bs;
            len +%= Nat64.fromNat(bs.size());
            var start = 0;
            if (0 < nx) {
                let n = Util.copy(nx, x, p);
                nx += n;
                if (nx == 64) {
                    block(Array.freeze(x));
                    nx := 0;
                };
                start += n;
                //p := Util.removeN(n, p);
            };
            if (64 <= (p.size() - start)) {
                let n = Nat64.toNat(Nat64.fromNat(p.size() - start) &^ 63);
                block_offset(p, start, n);
                start +=n;
                //p := Util.removeN(n, p);
            };
            if (0 < (p.size() - start)) {
                nx := Util.copy_offset(0, start, x, p);
            };
        };

        private func block(bs : [Nat8]) {
            var w : [var Nat32] = Array.init<Nat32>(64, 0);

            var h0 = h[0]; var h1 = h[1]; var h2 = h[2]; var h3 = h[3];
            var h4 = h[4]; var h5 = h[5]; var h6 = h[6]; var h7 = h[7];

            var start = 0;
            var len = bs.size();
            while (len >= 64) {
                for (i in Iter.range(0, 15)) {
                    let j = i * 4;
                    w[i] := Util.nat8to32(bs[start + j + 0]) << 24  | Util.nat8to32(bs[start + j + 1]) << 16
                          | Util.nat8to32(bs[start + j + 2]) << 8 | Util.nat8to32(bs[start + j + 3]);
                };
                for (i in Iter.range(16, 63)) {
                    let v1 = w[i-2];
                    let t1 = (Nat32.bitrotRight(v1, 17) ^ Nat32.bitrotRight(v1, 19)) ^ (v1 >> 10);
                    let v2 = w[i-15];
                    let t2 = (Nat32.bitrotRight(v2, 7) ^ Nat32.bitrotRight(v2, 18)) ^ (v2 >> 3);
                    w[i] := t1 +% w[i-7] +% t2 +% w[i - 16];
                };
                var a = h0; var b = h1; var c = h2; var d = h3;
                var e = h4; var f = h5; var g = h6; var h = h7;
                for (i in Iter.range(0, 63)) {
                    let t1 = h +% (Nat32.bitrotRight(e, 6) ^ Nat32.bitrotRight(e, 11) ^ Nat32.bitrotRight(e, 25)) +% ((e & f) ^ (^e & g)) +% K[i] +% w[i];
                    let t2 = (Nat32.bitrotRight(a, 2) ^ Nat32.bitrotRight(a, 13) ^ Nat32.bitrotRight(a, 22)) +% ((a & b) ^ (a & c) ^ (b & c));
                    h := g; g := f; f := e; e := d +% t1;
                    d := c; c := b; b := a; a := t1 +% t2;
                };
                h0 +%= a; h1 +%= b; h2 +%= c; h3 +%= d;
                h4 +%= e; h5 +%= f; h6 +%= g; h7 +%= h;
                start += 64;
                len -= 64;
            };
            h[0] := h0; h[1] := h1; h[2] := h2; h[3] := h3;
            h[4] := h4; h[5] := h5; h[6] := h6; h[7] := h7;
        };


        private func block_offset(bs : [Nat8], _start: Nat, _length: Nat) {
            var w : [var Nat32] = Array.init<Nat32>(64, 0);

            var h0 = h[0]; var h1 = h[1]; var h2 = h[2]; var h3 = h[3];
            var h4 = h[4]; var h5 = h[5]; var h6 = h[6]; var h7 = h[7];

            var start = _start;
            var len = _length;
            while (len >= 64) {
                for (i in Iter.range(0, 15)) {
                    let j = i * 4;
                    w[i] := Util.nat8to32(bs[start + j + 0]) << 24  | Util.nat8to32(bs[start + j + 1]) << 16
                          | Util.nat8to32(bs[start + j + 2]) << 8 | Util.nat8to32(bs[start + j + 3]);
                };
                for (i in Iter.range(16, 63)) {
                    let v1 = w[i-2];
                    let t1 = (Nat32.bitrotRight(v1, 17) ^ Nat32.bitrotRight(v1, 19)) ^ (v1 >> 10);
                    let v2 = w[i-15];
                    let t2 = (Nat32.bitrotRight(v2, 7) ^ Nat32.bitrotRight(v2, 18)) ^ (v2 >> 3);
                    w[i] := t1 +% w[i-7] +% t2 +% w[i - 16];
                };
                var a = h0; var b = h1; var c = h2; var d = h3;
                var e = h4; var f = h5; var g = h6; var h = h7;
                for (i in Iter.range(0, 63)) {
                    let t1 = h +% (Nat32.bitrotRight(e, 6) ^ Nat32.bitrotRight(e, 11) ^ Nat32.bitrotRight(e, 25)) +% ((e & f) ^ (^e & g)) +% K[i] +% w[i];
                    let t2 = (Nat32.bitrotRight(a, 2) ^ Nat32.bitrotRight(a, 13) ^ Nat32.bitrotRight(a, 22)) +% ((a & b) ^ (a & c) ^ (b & c));
                    h := g; g := f; f := e; e := d +% t1;
                    d := c; c := b; b := a; a := t1 +% t2;
                };
                h0 +%= a; h1 +%= b; h2 +%= c; h3 +%= d;
                h4 +%= e; h5 +%= f; h6 +%= g; h7 +%= h;
                start += 64;
                len -= 64;
            };
            h[0] := h0; h[1] := h1; h[2] := h2; h[3] := h3;
            h[4] := h4; h[5] := h5; h[6] := h6; h[7] := h7;
        };
    };
};
