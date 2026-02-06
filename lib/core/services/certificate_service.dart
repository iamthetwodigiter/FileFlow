import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:fileflow/core/exceptions/app_exceptions.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

class X509CertificateData {
  final String certPem;
  final String keyPem;

  X509CertificateData({required this.certPem, required this.keyPem});
}

class CertificateService {
  static X509CertificateData? _cachedCert;

  static Future<SecurityContext> generateSecurityContext() async {
    _cachedCert ??= await compute(_generateCertInIsolate, null);

    final context = SecurityContext(withTrustedRoots: false);
    context.useCertificateChainBytes(utf8.encode(_cachedCert!.certPem));
    context.usePrivateKeyBytes(utf8.encode(_cachedCert!.keyPem));

    return context;
  }

  static Future<X509CertificateData> _generateCertInIsolate(_) async {
    // Generate RSA Key Pair
    final keyParams = RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64);
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final keyGenerator = RSAKeyGenerator()
      ..init(ParametersWithRandom(keyParams, secureRandom));
    final keyPair = keyGenerator.generateKeyPair();
    final publicKey = keyPair.publicKey;
    final privateKey = keyPair.privateKey;

    // Create X.509 Certificate in DER format
    final certDer = _createX509CertificateDER(publicKey, privateKey);
    final keyDer = _encodePrivateKeyPKCS1(publicKey, privateKey);

    // Convert DER to PEM
    final certPem = _derToPem(certDer, 'CERTIFICATE');
    final keyPem = _derToPem(keyDer, 'RSA PRIVATE KEY');

    return X509CertificateData(certPem: certPem, keyPem: keyPem);
  }

  // Converts DER bytes to PEM format
  static String _derToPem(Uint8List der, String label) {
    final base64 = base64Encode(der);
    final lines = <String>[];
    lines.add('-----BEGIN $label-----');

    // Split into 64 character lines
    for (int i = 0; i < base64.length; i += 64) {
      final end = (i + 64 < base64.length) ? i + 64 : base64.length;
      lines.add(base64.substring(i, end));
    }

    lines.add('-----END $label-----');
    return lines.join('\n');
  }

  // Creates a self signed X.509 certificate in DER format
  static Uint8List _createX509CertificateDER(
    RSAPublicKey publicKey,
    RSAPrivateKey privateKey,
  ) {
    /*
      X.509 Certificate structure:
      Certificate ::= SEQUENCE {
        tbsCertificate       TBSCertificate,
        signatureAlgorithm   AlgorithmIdentifier,
        signatureValue       BIT STRING
      }
    */
    final tbsCert = _createTBSCertificate(publicKey);
    final signatureAlgorithm = _encodeAlgorithmicIdentifier();

    // Sign the TBS Certificate
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201'); // SHA256 with RSA OID
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final signature = signer.generateSignature(tbsCert);

    // Encode signature as BIT String
    final signatureBitString = _encodeBitString(signature.bytes);

    // Combine into final certificate
    return _encodeSequence([tbsCert, signatureAlgorithm, signatureBitString]);
  }

  // Creates TBSCertificate (To Be Signed Certificate)
  static Uint8List _createTBSCertificate(RSAPublicKey publicKey) {
    /*
      TBSCertificate ::= SEQUENCE {
        version         [0]  EXPLICIT Version DEFAULT v1,
        serialNumber         CertificateSerialNumber,
        signature            AlgorithmIdentifier,
        issuer               Name,
        validity             Validity,
        subject              Name,
        subjectPublicKeyInfo SubjectPublicKeyInfo
      }
    */
    final version = _encodeVersion();
    final serialNumber = _encodeInteger(BigInt.from(Random().nextInt(1000000)));
    final signature = _encodeAlgorithmicIdentifier();
    final issuer = _encodeName('FileFlow');
    final validity = _encodeValidity();
    final subject = _encodeName('FileFlow');
    final subjectPublicKeyInfo = _encodePublicKeyInfo(publicKey);

    return _encodeSequence([
      version,
      serialNumber,
      signature,
      issuer,
      validity,
      subject,
      subjectPublicKeyInfo
    ]);
  }

  static Uint8List _encodeVersion() {
    // Version ::= INTEGER { v1(0), v2(1), V3(2) }
    // Explicitly tagged as [0]
    final versionInt = _encodeInteger(BigInt.from(2));
    return _encodeExplicitTag(0, versionInt);
  }

  static Uint8List _encodeAlgorithmicIdentifier() {
    /*
      AlgorithmIdentifier ::= SEQUENCE {
        algorithm  OBJECT IDENTIFIER,
        parameters ANY DEFINED BY algorithm OPTIONAL
      }
      SHA256withRSA OID: 1.2.840.113549.1.1.11
    */
    final oid = _encodeOID([1, 2, 840, 113549, 1, 1, 11]);
    final nullParams = Uint8List.fromList([0x05, 0x00]); // NULL
    return _encodeSequence([oid, nullParams]);
  }

  static Uint8List _encodeName(String commonName) {
    // Name ::= SEQUENCE OF RelativeDistinguishedName
    // RelativeDistinguishedName ::= SET OF AttributeTypeAndValue
    // AttributeTypeAndValue ::= SEQUENCE { type OBJECT IDENTIFIER, value ANY }
    
    // CN OID: 2.5.4.3
    final cnOID = _encodeOID([2, 5, 4, 3]);
    final cnValue = _encodeUTF8String(commonName);
    final attrTypeAndValue = _encodeSequence([cnOID, cnValue]);
    final rdn = _encodeSet([attrTypeAndValue]);
    return _encodeSequence([rdn]);
  }

  static Uint8List _encodeValidity() {
    /*
      Validity ::= SEQUENCE {
        notBefore Time,
        notAfter  Time
      }
    */
    final now = DateTime.now().toUtc();
    final notBefore = _encodeUTCTime(now);
    final notAfter = _encodeUTCTime(now.add(const Duration(days: 365)));
    return _encodeSequence([notBefore, notAfter]);
  }

  static Uint8List _encodePublicKeyInfo(RSAPublicKey publicKey) {
    /*
      SubjectPublicKeyInfo ::= SEQUENCE {
        algorithm        AlgorithmIdentifier,
        subjectPublicKey BIT STRING
      }
    */
    
    // RSA encryption OID: 1.2.840.113549.1.1.1
    final algorithm = _encodeSequence([
      _encodeOID([1, 2, 840, 113549, 1, 1, 1]),
      Uint8List.fromList([0x05, 0x00]), // NULL
    ]);
    
    /*
      RSAPublicKey ::= SEQUENCE {
        modulus           INTEGER,
        publicExponent    INTEGER
      }
    */
    final rsaPublicKey = _encodeSequence([
      _encodeInteger(publicKey.modulus!),
      _encodeInteger(publicKey.exponent!),
    ]);
    
    final subjectPublicKey = _encodeBitString(rsaPublicKey);
    return _encodeSequence([algorithm, subjectPublicKey]);
  }

  // Encodes RSA Private Key in PKCS#1 format
  static Uint8List _encodePrivateKeyPKCS1(RSAPublicKey publicKey, RSAPrivateKey privateKey) {
    /*
      RSAPrivateKey ::= SEQUENCE {
        version           Version,
        modulus           INTEGER,
        publicExponent    INTEGER,
        privateExponent   INTEGER,
        prime1            INTEGER,
        prime2            INTEGER,
        exponent1         INTEGER,
        exponent2         INTEGER,
        coefficient       INTEGER
      }
    */
    return _encodeSequence([
      _encodeInteger(BigInt.zero), // version
      _encodeInteger(privateKey.modulus!),
      _encodeInteger(publicKey.exponent!), // Use public exponent from public key
      _encodeInteger(privateKey.privateExponent!),
      _encodeInteger(privateKey.p!),
      _encodeInteger(privateKey.q!),
      _encodeInteger(privateKey.privateExponent! % (privateKey.p! - BigInt.one)),
      _encodeInteger(privateKey.privateExponent! % (privateKey.q! - BigInt.one)),
      _encodeInteger(privateKey.q!.modInverse(privateKey.p!)),
    ]);
  }

  static Uint8List _encodeSequence(List<Uint8List> elements) {
    return _encodeWithTag(0x30, _concatenate(elements));
  }

  static Uint8List _encodeSet(List<Uint8List> elements) {
    return _encodeWithTag(0x31, _concatenate(elements));
  }

  static Uint8List _encodeInteger(BigInt value) {
    var bytes = _bigIntToBytes(value);
    // Add leading zero if high bit is set (to indicate positive number)
    if(bytes.isNotEmpty && bytes[0] & 0x80 != 0) {
      bytes = Uint8List.fromList([0, ...bytes]);
    }
    return _encodeWithTag(0x02, bytes);
  }

  static Uint8List _encodeBitString(Uint8List data) {
    final content = Uint8List.fromList([0, ...data]); // 0 = no unused bits
    return _encodeWithTag(0x03, content);
  }

  static Uint8List _encodeUTF8String(String str) {
    final bytes = Uint8List.fromList(str.codeUnits);
    return _encodeWithTag(0x0C, bytes);
  }

  static Uint8List _encodeUTCTime(DateTime dateTime) {
    // Format: YYMMDDHHmmSSZ
    final year = (dateTime.year % 100).toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    final timeStr = '$year$month$day$hour$minute${second}Z';
    final bytes = Uint8List.fromList(timeStr.codeUnits);
    return _encodeWithTag(0x17, bytes);
  }

  static Uint8List _encodeOID(List<int> oid) {
    if(oid.length < 2) throw InvalidArgument('OID must have at least 2 components', argumentName: 'oid');

    final bytes = <int>[];
    // First byte encodes first two components
    bytes.add(oid[0]*40 + oid[1]);

    // Remaining components
    for(int i=2; i<oid.length; i++) {
      bytes.addAll(_encodeOIDComponent(oid[i]));
    }
    return _encodeWithTag(0x06, Uint8List.fromList(bytes));
  }

  static List<int> _encodeOIDComponent(int value) {
    if(value < 128) return [value];

    final bytes = <int>[];
    var v = value;
    while(v > 0) {
      bytes.insert(0, (v & 0x7F) | (bytes.isEmpty ? 0 : 0x80));
      v >>= 7;
    }
    return bytes;
  }

  static Uint8List _encodeExplicitTag(int tagNumber, Uint8List content) {
    final tag = 0xA0 | tagNumber;
    return _encodeWithTag(tag, content);
  }

  static Uint8List _encodeWithTag(int tag, Uint8List content) {
    final length = _encodeLength(content.length);
    return Uint8List.fromList([tag, ...length, ...content]);
  }

  static Uint8List _encodeLength(int length) {
    if(length < 128) {
      return Uint8List.fromList([length]);

    }
    final lengthBytes = _intToBytes(length);
    return Uint8List.fromList([0x80 | lengthBytes.length, ...lengthBytes]);
  }

  static Uint8List _bigIntToBytes(BigInt value) {
    if(value == BigInt.zero) return Uint8List.fromList([0]);

    final bytes = <int>[];
    var v = value;
    while(v > BigInt.zero) {
      bytes.insert(0, (v & BigInt.from(0xFF)).toInt());
      v >>= 8;
    }
    return Uint8List.fromList(bytes);
  }

  static Uint8List _intToBytes(int value) {
    final bytes = <int>[];
    var v = value;
    while(v > 0) {
      bytes.insert(0, v & 0xFF);
      v >>= 8;
    }
    return Uint8List.fromList(bytes);
  }

  static Uint8List _concatenate(List<Uint8List> arrays) {
    final totalLength = arrays.fold<int>(0, (sum, arr) => sum + arr.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final arr in arrays) {
      result.setRange(offset, offset + arr.length, arr);
      offset += arr.length;
    }
    return result;
  }
}
