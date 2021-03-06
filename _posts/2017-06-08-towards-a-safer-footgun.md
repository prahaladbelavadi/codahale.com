---
title: Towards A Safer Footgun
layout: post
summary: In which encryption's splash damage is somewhat nerfed.
---

Modern symmetric encryption is built around [Authenticated Encryption with Associated
Data][AEAD-INT] (AEAD) constructions: combinations of ciphers and message authentication codes which
provide strong guarantees of both _confidentiality_ and _integrity_. These constructions avoid the
["doom principle"][DP] which made so many older cryptosystems vulnerable to online attacks, but many
of the standard AEAD constructions have problems of their own.

### What's an AEAD?

An AEAD is essentially a pair of functions:
`\[
\begin{array}{rccc}
Encrypt\colon & (K, N, M, D) & \to & (C, T)\\
Decrypt\colon & (K, N, C, T, D) & \to & (M) \coprod \varnothing\\
\end{array}
\]`
Given a key (`\(K\)`), a nonce (`\(N\)`), a message (`\(M\)`), and some associated data (`\(D\)`),
the `\(Encrypt\)` function returns the ciphertext (`\(C\)`) and an authentication tag (`\(T\)`).
(The data is not included in the ciphertext.) Passing the same key, nonce, data, ciphertext, and tag
to the `\(Decrypt\)` function will return the original message. If _any_ bit of the key, nonce,
data, ciphertext, or tag are altered, however, `\(Decrypt\)` will return nothing (or an error).

### Fantastical constructions…

The addition of [AEAD-based ciphersuites][TLS-AEAD] to TLS 1.2 gave the world a set of standard AEAD
constructions, including the ubiquitous [AES-GCM][TLS-GCM] and the more recent
[ChaCha20-Poly1305][TLS-CHACHA]. These have found their way into [standard libraries][GO-AEAD],
[high-level libraries][LIBSOD], [open-source projects][K8S], and [online services][KMS], largely
displacing a small ecosystem of lightly-scrutinized, ad-hoc constructions. This is a positive
development, but it's worth noting that the proliferation of these constructions outside of the
context for which they were developed--i.e. TLS--has exposed us to additional cryptographic
challenges.

### …and where to find them

TLS 1.2 uses AEADs to protect records--batches of data being sent or received via a TLS
connection--and the standard IETF AEAD constructions are designed to take advantage of specific
details of that context. For one, TLS connections are protected using randomly generated,
per-session keys. For two, TLS records have unique, sequenced identifiers to prevent an attacker
from dropping or duplicating records without detection.

As a result, all IETF AEAD standards use 96-bit nonces derived from the record identifiers, which
are guaranteed to be unique inside a single connection. Because the keys are also scoped to a single
connection, there is less risk of accidentally re-using a key/nonce pair. That's an important
consideration, because their security guarantees of confidentiality and integrity are completely
broken if a key/nonce pair is ever re-used.

### Every cloud has a granite lining

AES-GCM provides confidentiality by using AES in counter mode to encrypt the data. A 128-bit
counter, which is derived from the nonce, is encrypted and the resulting key stream is `xor`-ed with
the plaintext to produce the ciphertext. If a key/nonce pair is used for two different messages, an
attacker can recover `\(M_1 \oplus M_2\)`, which will reveal information about both messages.
ChaCha20-Poly1305 uses ChaCha20, a stream cipher, which is vulnerable to the same attack should a 
nonce ever be reused.

AES-GCM and ChaCha20-Poly1305 both provide integrity by hashing the ciphertext with polynomial
message authentication codes (GHASH for the former, Poly1305 for the latter). These types of
algorithms are vulnerable to [forgery attacks][GCM-WEAK] should an authentication key ever be
reused. ChaCha20-Poly1305's construction [is resilient this sort of attack][AE-MOD] because the
authentication key is derived from the ChaCha20 keystream, but AES-GCM is [very fragile][GCM-FRAG]
and fails catastrophically in the event of key/nonce reuse.

Because key/nonce reuse is essentially impossible in the context of a TLS connection, these
constructions trade nonce-misuse resistance for performance. But what about in other contexts?
 
### Betting one's shirt 

Without a naturally-occurring nonce like TLS's record identifiers, developers often [generate random
nonces][K8S-NONCE] on the assumption that the probability of two operations picking the same 96-bit
value is low enough to safely ignore. For a few operations, that's certainly correct, but thanks to
the [birthday problem][BIRTHDAY], those probabilities get big quick. At what point does that become
unsafe?

Thankfully, NIST made [concrete recommendations][GCM-REC] regarding this:

> The probability that the authenticated encryption function ever will be invoked with the same IV 
> and the same key on two (or more) distinct sets of input data shall be no greater than 
> `\(2^{-32}\)`.

> …unless an implementation only uses 96-bit IVs that are generated by the deterministic 
> construction:
>
> The total number of invocations of the authenticated encryption function shall not exceed
> `\(2^{32}\)`, including all IV lengths and all instances of the authenticated encryption function 
> with the given key. 

If we're randomly generating nonces, then, we should encrypt no more than 4,294,967,296 messages
with the same key. That's a lot, right? Well, no.

As an example, let's assume we've got a web application running on a bunch of independent servers
and we're using AES-GCM or ChaCha20-Poly1305 to secure something in each request with a shared key.
At 100 requests a second, we won't need to rotate keys for 16 months. At 1,000 requests per second,
we'll need to rotate keys every 50 days or so. At 10,000 requests per second, we'll be rotating keys
more than once a week. At 100,000 requests per second, we'll be rotating keys more than twice a day.

What's a developer to do?

### A safer footgun

The solution, broadly speaking, is a class of AEAD constructions which are called "nonce-misuse
resistant", which means they don't immediately fall apart should a key/nonce pair be re-used. This
doesn't mean, however, they can tolerate arbitrary amounts of re-use, but rather their security
bounds degrade much more slowly with each re-used nonce.

The most practical nonce-misuse resistant AEAD proposal, I think, is [AES-GCM-SIV][AES-GCM-SIV], an
improvement of [GCM-SIV][GCM-SIV] designed for use in Google's [QUIC][QUIC] protocol. QUIC allows
clients to prove they're actually using a particular IP address by issuing cryptographic
"source-address" tokens.

> Since a central allocation system for nonces is not operationally viable, random selection of
> nonces is the only possibility. AES-GCM’s limit of `\(2^{32}\)` random nonces (per key) suggests 
> that, even if the system rotated these secret keys daily, it could not issue more than about 50K
> tokens per second. However, in order to process DDoS attacks the system may need to sustain 
> issuance of several hundred million per second.

As a result, AES-GCM-SIV is designed with a few important properties:

1. For encryption, it uses AES, which is well-studied and widely supported in hardware thanks to
   AES-NI.
2. For authentication, it uses a MAC called POLYVAL, which is essentially GCM's GHASH without the
   byte swapping. As a result, it can leverage Intel's `PCLMULQDQ` instruction to achieve speeds
   only slightly slower than GCM, despite requiring two full passes on each message.
3. Its security bounds degrade almost linearly with nonce reuse, improving on GCM-SIV's quadratic 
   degradation, and making it ideal for use in systems like QUIC where GCM's per-key limits are
   infeasible.
4. Unlike constructions like [XSalsa20][XSALSA20], which protect against nonce reuse by increasing 
   the nonce size, AES-GCM-SIV still uses 96-bit nonces. For a system like QUIC, which may peak at
   `\(10^8\)` operations per second, this matters. At that rate, XSalsa20 would require 9.6Gb/s more
   bandwidth.
   
AES-GCM-SIV is [not yet an IETF standard][AES-GCM-SIV-AEAD], but it's in progress. Once
standardized, however, I can see it being the recommended construction for authenticated encryption.

As you may have guessed, I've written a [Java library][JAVA] which implements the most recent draft
specification for AES-GCM-SIV. It's based on the AES and GHASH implementations in BouncyCastle, so
it doesn't leverage the performance and security benefits of AES-NI and `PCLMULQDQ` instructions,
making it around twice as slow as AES-GCM. It's still plenty fast (~40-50µs for a 1KiB message),
however.

### tl;dr

AEADs have been a critical development in making symmetric encryption safe to use, but most standard
constructions were developed to be used in contexts with deterministic nonces, like TLS's record
identifiers. In contexts with long-lived keys and where nonces must be randomly generated, the
Birthday Problem makes nonces much more likely to collide in systems performing many operations.
Should a nonce be reused, the security guarantees of most standard AEADs are null and void--an
attacker can recover plaintexts, forge messages, etc.

Cryptographers have been working on "nonce-misuse resistant" AEADs, which have security bounds which
degrade more gracefully when nonces are re-used. Of these, AES-GCM-SIV is the most promising and,
once standardized, will be a better choice than AES-GCM in contexts where nonces must be generated
randomly.

---

### Updated June 10, 2017

* Fixed my assertions about ChaCha20-Poly1305 forgery attacks. Thanks,
  [@dchest](https://twitter.com/dchest/status/863295115477094400)! 

---

_Thanks to [Thomas Ptacek](https://twitter.com/tqbf) for reviewing this post. Any mistakes in this
article are mine, not his._

[DP]: https://moxie.org/blog/the-cryptographic-doom-principle/
[AEAD-INT]: https://tools.ietf.org/html/rfc5116
[TLS-AEAD]: https://tools.ietf.org/html/rfc5246#section-6.2.3.3
[TLS-GCM]: https://tools.ietf.org/html/rfc5288
[TLS-CHACHA]: https://tools.ietf.org/html/rfc7905
[GO-AEAD]: https://golang.org/pkg/crypto/cipher/#AEAD
[LIBSOD]: https://download.libsodium.org/doc/secret-key_cryptography/ietf_chacha20-poly1305_construction.html
[K8S-NONCE]: https://github.com/kubernetes/kubernetes/blob/f89d2493f100bf7268b8778d7e077e7d5383c50b/staging/src/k8s.io/apiserver/pkg/storage/value/encrypt/aes/aes.go#L69-L71
[K8S]: https://github.com/kubernetes/kubernetes/blob/f89d2493f100bf7268b8778d7e077e7d5383c50b/staging/src/k8s.io/apiserver/pkg/storage/value/encrypt/aes/aes.go#L69-L71
[KMS]: https://d0.awsstatic.com/whitepapers/KMS-Cryptographic-Details.pdf
[GCM-REC]: http://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38d.pdf
[GCM-SIV]: https://eprint.iacr.org/2015/102.pdf
[AES-GCM-SIV]: https://eprint.iacr.org/2017/168
[AES-GCM-SIV-AEAD]: https://tools.ietf.org/html/draft-irtf-cfrg-gcmsiv-05
[BIRTHDAY]: https://en.wikipedia.org/wiki/Birthday_problem
[QUIC]: https://www.chromium.org/quic
[XSALSA20]: https://cr.yp.to/snuffle/xsalsa-20081128.pdf
[JAVA]: https://github.com/codahale/aes-gcm-siv
[AE-MOD]: https://eprint.iacr.org/2017/239.pdf
[GCM-WEAK]: https://eprint.iacr.org/2013/144.pdf
[GCM-FRAG]: https://eprint.iacr.org/2013/157.pdf