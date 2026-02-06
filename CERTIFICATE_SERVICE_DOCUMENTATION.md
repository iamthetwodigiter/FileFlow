# Certificate Service Documentation

## Overview
The `CertificateService` generates and manages **self-signed X.509 certificates** with **RSA-2048 encryption** and **SHA-256 signing** for TLS communication between FileFlow peers.

**Location:** `lib/core/services/certificate_service.dart`  
**Purpose:** Provide secure TLS context for peer-to-peer encrypted connections

---

## Key Components

### 1. **X509CertificateData Class**
Data container holding both certificate and private key in PEM format.
```dart
class X509CertificateData {
  final String certPem;    // PEM-encoded certificate
  final String keyPem;     // PEM-encoded private key
}
```

### 2. **CertificateService Class**
Main service with static methods for certificate generation and context creation.

---

## Certificate Generation Process

### Entry Point: `generateSecurityContext()`
```
generateSecurityContext()
  ├─ Check _cachedCert (reuse if exists)
  ├─ Call compute(_generateCertInIsolate) in background isolate (non-blocking)
  ├─ Create SecurityContext
  ├─ Load certificate PEM into context
  ├─ Load private key PEM into context
  └─ Return ready-to-use context for TLS
```

**Why in isolate?** RSA 2048-bit key generation is CPU-intensive (~500ms). Computing in isolate prevents UI freeze.

**Caching strategy:** `_cachedCert` stores generated certificate for app session. Reused for all connections = same security identity per app instance.

---

## Internal Generation Steps

### Step 1: `_generateCertInIsolate()`

#### RSA Key Pair Generation
```
Create KeyGeneratorParameters:
  ├─ e (public exponent) = 65537 (standard)
  ├─ Key size = 2048 bits
  └─ Certainty = 64 (Miller-Rabin iterations)

Seed SecureRandom:
  ├─ Use Random.secure() for 32 bytes of entropy
  ├─ Create FortunaRandom (cryptographically secure PRNG)
  └─ Feed entropy via KeyParameter

Generate KeyPair:
  ├─ RSAKeyGenerator initialized with seeded random
  ├─ Produces publicKey: RSAPublicKey (modulus + exponent)
  └─ Produces privateKey: RSAPrivateKey (d, p, q, etc.)
```

#### DER Format Encoding (Binary X.509)
```
Create TBSCertificate (To Be Signed):
  ├─ Version: 3 (explicit tag [0])
  ├─ Serial Number: Random 32-bit integer
  ├─ Signature Algorithm: SHA256withRSA (OID: 1.2.840.113549.1.1.11)
  ├─ Issuer DN: CN=FileFlow
  ├─ Validity: Now → Now + 365 days
  ├─ Subject DN: CN=FileFlow
  └─ SubjectPublicKeyInfo: Encoded RSA public key

Sign TBSCertificate:
  ├─ Use RSASigner with SHA-256 algorithm
  ├─ Input: SHA256withRSA OID = "0609608648016503040201"
  ├─ Sign with private key
  ├─ Output: Raw signature bytes (256 bytes for 2048-bit RSA)
  └─ Encode as BIT STRING

Final Certificate (DER):
  ├─ TBSCertificate (signed data)
  ├─ Signature Algorithm Identifier
  └─ Signature (DER BIT STRING)
```

#### PEM Format Conversion
```
Convert both DER outputs to PEM:
  ├─ Base64 encode DER
  ├─ Split into 64-character lines
  ├─ Wrap with:
  │   ├─ "-----BEGIN CERTIFICATE-----"
  │   ├─ Base64 lines
  │   └─ "-----END CERTIFICATE-----"
  └─ Same for private key with "RSA PRIVATE KEY"
```

---

## Certificate Structure (X.509 Standard)

### Byte-Level Breakdown

#### Certificate Container (DER-encoded SEQUENCE)
```
Tag:    0x30 (SEQUENCE)
Length: Variable (usually 500-600 bytes)
Contents:
  [1] TBSCertificate
  [2] SignatureAlgorithm
  [3] SignatureValue
```

#### TBSCertificate (SEQUENCE)
```
[0] Version [EXPLICIT 0]
    └─ 0x02 0x01 0x02 (INTEGER = 2, meaning v3)

[1] SerialNumber (INTEGER)
    └─ Random value, e.g., 0x02 0x04 0x00 0x0F A2 3B

[2] Signature Algorithm (SEQUENCE)
    ├─ OID: 1.2.840.113549.1.1.11 (sha256WithRSAEncryption)
    └─ Parameters: NULL

[3] Issuer (Name/SEQUENCE)
    └─ CN=FileFlow (X.500 distinguished name)

[4] Validity (SEQUENCE)
    ├─ NotBefore: UTCTime (YYMMDDHHmmSSZ)
    └─ NotAfter: UTCTime (365 days later)

[5] Subject (Name/SEQUENCE)
    └─ CN=FileFlow (same as issuer for self-signed)

[6] SubjectPublicKeyInfo (SEQUENCE)
    ├─ Algorithm (SEQUENCE)
    │   ├─ OID: 1.2.840.113549.1.1.1 (rsaEncryption)
    │   └─ NULL parameters
    └─ PublicKey (BIT STRING)
        └─ RSAPublicKey (SEQUENCE)
            ├─ modulus (2048-bit INTEGER)
            └─ publicExponent (INTEGER = 65537)
```

#### RSAPrivateKey (PKCS#1 Format)
```
SEQUENCE {
  [0] version: 0x00
  [1] modulus: n (2048-bit)
  [2] publicExponent: e (usually 65537)
  [3] privateExponent: d
  [4] prime1: p
  [5] prime2: q
  [6] exponent1: d mod (p-1)
  [7] exponent2: d mod (q-1)
  [8] coefficient: q^-1 mod p
}
```

---

## Cryptographic Details

### RSA Parameters
| Parameter | Value | Meaning |
|-----------|-------|---------|
| Key Size | 2048 bits | Provides ~112 bits symmetric equivalent security |
| Exponent (e) | 65537 (0x10001) | Standard choice for RSA, balances speed/security |
| Modulus (n) | Product of p×q | ~617 decimal digits |
| Certainty | 64 iterations | Miller-Rabin primality test false positive < 2^-128 |

### SHA-256 Signature
| Property | Value |
|----------|-------|
| Algorithm | SHA256withRSA (RSASSA-PKCS1-v1_5) |
| OID | 1.2.840.113549.1.1.11 |
| Hash Output | 256 bits (32 bytes) |
| Signature Output | 2048 bits (256 bytes) |
| Signature Encoding | PKCS#1 v1.5 padding |

### Time Validity
- **Generated**: Current UTC time
- **Valid Until**: Current UTC + 365 days
- **Format**: YYMMDDHHmmSSZ (e.g., "260204120000Z")

---

## Encoding Functions (ASN.1 DER)

### Tag-Length-Value (TLV) Structure
```
[1 byte]    [1-4 bytes]    [variable length]
   Tag         Length           Value/Content
```

### Implemented Encoding Methods

| Method | Tag | Purpose |
|--------|-----|---------|
| `_encodeSequence()` | 0x30 | Container for multiple fields |
| `_encodeSet()` | 0x31 | Unordered collection |
| `_encodeInteger()` | 0x02 | Arbitrary-precision integers |
| `_encodeBitString()` | 0x03 | Bit sequences (e.g., signatures) |
| `_encodeUTF8String()` | 0x0C | Text strings |
| `_encodeUTCTime()` | 0x17 | UTC timestamps |
| `_encodeOID()` | 0x06 | Object identifiers |
| `_encodeExplicitTag()` | 0xAx | Context-specific tagged values |

### Length Encoding
```
Length < 128:           [1 byte] length
Length >= 128:          [0x80 | numBytes] [bytes...]
                        Example: 256 bytes = 0x82 0x01 0x00
```

### Integer Encoding
```
Requirement: Most significant bit = 0 (to indicate positive)
Action: Prepend 0x00 if high bit set
```

### OID Encoding
```
Standard format:        1.2.840.113549.1.1.11
Compressed form:        First: 1×40 + 2 = 42
                        Remaining: 840, 113549, 1, 1, 11 each base-128 encoded
Bytes for SHA256RSA:    06 09 2A 86 48 86 F7 0D 01 01 0B
```

---

## Usage in FileFlow

### Connection Establishment
```
Device A (Client):
  1. Call generateSecurityContext()
  2. Get SecurityContext with self-signed certificate
  3. Use for SecureSocket.connect() to Device B
  4. Both sides verify each other's self-signed cert

Device B (Server):
  1. Call generateSecurityContext() (same process)
  2. Get SecurityContext with self-signed certificate
  3. Use for SecureServerSocket.bind() on port 4000
  4. Accept incoming connections with same context
```

### Certificate Validation
- **Disabled** one-way verification: `SecurityContext(withTrustedRoots: false)`
- **Reason**: Self-signed certificates aren't in system trust store
- **Security**: PIN authentication provides additional validation
- **Note**: Both peers use self-signed certs, no CA chain needed

---

## Performance Characteristics

| Operation | Time | Location |
|-----------|------|----------|
| RSA 2048-bit generation | ~500ms | Isolate |
| Certificate caching | Instant | Memory |
| DER encoding | <1ms | Isolate |
| PEM encoding | <1ms | Isolate |
| SecurityContext creation | <1ms | Main thread |
| TLS handshake | ~100-200ms | Network |

---

## Security Properties

### What It Provides
✅ **Encryption**: All data encrypted in transit via TLS  
✅ **Integrity**: Message authentication via HMAC in TLS  
✅ **Forward Secrecy**: Ephemeral DH for key exchange (in TLS layer)  
✅ **Self-Signed Identity**: Device verifiable via fingerprint

### What It Doesn't Provide
❌ **Certificate Pinning**: No pin validation (would require persistent storage)  
❌ **Certificate Chain**: No CA verification (not needed for LAN)  
❌ **Revocation Checking**: No CRL or OCSP (single-app certificates)  
❌ **Anti-Replay**: No nonce tracking (application level handles it)

### Threat Mitigation
| Threat | Mitigation |
|--------|-----------|
| Network eavesdropping | TLS encryption |
| Packet modification | TLS HMAC integrity check |
| Man-in-the-middle | PIN authentication (out-of-band) |
| Replay attacks | Transfer ID validation |
| Certificate spoofing | PIN validation on connection |

---

## Caching & Lifecycle

### Certificate Lifetime
- **Created**: When app first calls `generateSecurityContext()`
- **Cached**: Static variable `_cachedCert` for app session
- **Reused**: All subsequent connections use same certificate
- **Expires**: When app terminates or restarts

### Security Implication
- **Pro**: Consistent device identity during session
- **Con**: New certificate on app restart (not persistent)
- **Workaround**: Pin certificate fingerprint to device ID (not implemented)

---

## Error Handling

### Potential Failures
```
generateSecurityContext():
  ├─ Isolate.compute() timeout → TimeoutException
  ├─ OOM during key generation → OutOfMemoryError
  └─ SecurityContext.useCertificateChainBytes() → TlsException

_generateCertInIsolate():
  ├─ Random seed insufficient → Unlikely, fixed seed size
  ├─ Big integer arithmetic overflow → Caught by BigInt checks
  └─ Integer to bytes conversion → Handled by _bigIntToBytes()
```

### Current Implementation
- **No explicit error handling** in certificate service
- **Errors bubble up** to connection_repository.dart
- **Recommended**: Add try-catch in generateSecurityContext() with logging

---

## Verification Checklist

For validating certificate generation:

```
✓ PEM format correct (-----BEGIN/END tags)
✓ Base64 encoding valid (64-char line breaks)
✓ DER structure conforms to X.509 v3 standard
✓ Serial number unique per generation
✓ Signature verifiable with own public key
✓ Validity dates set correctly (now → +365 days)
✓ RSA modulus is 2048 bits
✓ Public exponent is 65537
✓ Subject = Issuer (self-signed)
✓ OID for SHA256RSA correct: 1.2.840.113549.1.1.11
✓ Certificate loads without error in SecurityContext
✓ TLS handshake succeeds with generated context
```

---

## Related Files

- **Connection Repository**: Uses `generateSecurityContext()` for TLS
- **Connection ViewModel**: Initiates server/client connections
- **Transfer Service (Android)**: Foreground service notifications
- **Security Verification**: Details in SECURITY_AND_FUNCTIONALITY_VERIFICATION.dart

---

## References

- **X.509 Standard**: RFC 5280 (Internet X.509 Public Key Infrastructure)
- **ASN.1 DER Encoding**: ITU-T X.690
- **RSA Cryptography**: PKCS#1 v2.1 (RFC 3447)
- **SHA-256**: FIPS 180-4
- **Dart SecurityContext**: Flutter platform channels to platform-specific SSL/TLS
