// Copyright Keefer Taylor, 2019.

import CommonCrypto
import Foundation

/// A static utility class which provides Base58 encoding and decoding functionality.
public enum Base58 {
  /// Length of checksum appended to Base58Check encoded strings.
  private static let checksumLength = 4

  private static let alphabet = [UInt8]("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
  private static let zero = BigUInt(0)
  private static let radix = BigUInt(alphabet.count)

  /// Encode the given bytes into a Base58Check encoded string.
  /// - Parameter bytes: The bytes to encode.
  /// - Returns: A base58check encoded string representing the given bytes, or nil if encoding failed.
  public static func base58CheckEncode(_ bytes: [UInt8]) -> String {
    let checksum = calculateChecksum(bytes)
    let checksummedBytes = bytes + checksum
    return Base58.base58Encode(checksummedBytes)
  }

  /// Decode the given Base58Check encoded string to bytes.
  /// - Parameter input: A base58check encoded input string to decode.
  /// - Returns: Bytes representing the decoded input, or nil if decoding failed.
  public static func base58CheckDecode(_ input: String) -> [UInt8]? {
    guard let decodedChecksummedBytes = base58Decode(input) else {
      return nil
    }

    let decodedChecksum = decodedChecksummedBytes.suffix(checksumLength)
    let decodedBytes = decodedChecksummedBytes.prefix(upTo: decodedChecksummedBytes.count - checksumLength)
    let calculatedChecksum = calculateChecksum([UInt8](decodedBytes))

    guard decodedChecksum.elementsEqual(calculatedChecksum, by: { $0 == $1 }) else {
      return nil
    }
    return Array(decodedBytes)
  }

  /// Encode the given bytes to a Base58 encoded string.
  /// - Parameter bytes: The bytes to encode.
  /// - Returns: A base58 encoded string representing the given bytes, or nil if encoding failed.
  public static func base58Encode(_ bytes: [UInt8]) -> String {
    var answer: [UInt8] = []
    var integerBytes = BigUInt(Data(bytes))

    while integerBytes > 0 {
      let (quotient, remainder) = integerBytes.quotientAndRemainder(dividingBy: radix)
      answer.insert(alphabet[Int(remainder)], at: 0)
      integerBytes = quotient
    }

    let prefix = Array(bytes.prefix { $0 == 0 }).map { _ in alphabet[0] }
    answer.insert(contentsOf: prefix, at: 0)

    // swiftlint:disable force_unwrapping
    // Force unwrap as the given alphabet will always decode to UTF8. 
    return String(bytes: answer, encoding: String.Encoding.utf8)!
    // swiftlint:enable force_unwrapping
  }

  /// Decode the given base58 encoded string to bytes.
  /// - Parameter input: The base58 encoded input string to decode.
  /// - Returns: Bytes representing the decoded input, or nil if decoding failed.
  public static func base58Decode(_ input: String) -> [UInt8]? {
    var answer = zero
    var i = BigUInt(1)
    let byteString = [UInt8](input.utf8)

    for char in byteString.reversed() {
      guard let alphabetIndex = alphabet.firstIndex(of: char) else {
        return nil
      }
      answer += (i * BigUInt(alphabetIndex))
      i *= radix
    }

    let bytes = answer.serialize()
    return Array(byteString.prefix { i in i == alphabet[0] }) + bytes
  }

  /// Calculate a checksum for a given input by hashing twice and then taking the first four bytes.
  /// - Parameter input: The input bytes.
  /// - Returns: A byte array representing the checksum of the input bytes.
  private static func calculateChecksum(_ input: [UInt8]) -> [UInt8] {
    let hashedData = sha256(input)
    let doubleHashedData = sha256(hashedData)
    let doubleHashedArray = Array(doubleHashedData)
    return Array(doubleHashedArray.prefix(checksumLength))
  }

  /// Create a sha256 hash of the given data.
  /// - Parameter data: Input data to hash.
  /// - Returns: A sha256 hash of the input data.
  private static func sha256(_ data: [UInt8]) -> [UInt8] {
    let res = NSMutableData(length: Int(CC_SHA256_DIGEST_LENGTH))!
    CC_SHA256(
      (Data(data) as NSData).bytes,
      CC_LONG(data.count),
      res.mutableBytes.assumingMemoryBound(to: UInt8.self)
    )
    return [UInt8](res as Data)
  }
}

private struct _Base58: Encoding {
    static let baseAlphabets = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    static var zeroAlphabet: Character = "1"
    static var base: Int = 58
    
    static func sizeFromByte(size: Int) -> Int {
        return size * 138 / 100 + 1
    }
    static func sizeFromBase(size: Int) -> Int {
        return size * 733 / 1000 + 1
    }
}

public extension Base58 {
    static func encodeDataToString(_ bytes: Data?) -> String {
        guard let byte = bytes else {
            return ""
        }
        return _Base58.encode(byte)
    }
    static func decodeStringToData(_ string: String) -> Data? {
        return _Base58.decode(string)
    }
}

private protocol Encoding {
    static var baseAlphabets: String { get }
    static var zeroAlphabet: Character { get }
    static var base: Int { get }
    
    // log(256) / log(base), rounded up
    static func sizeFromByte(size: Int) -> Int
    // log(base) / log(256), rounded up
    static func sizeFromBase(size: Int) -> Int
    
    // Public
    static func encode(_ bytes: Data) -> String
    static func decode(_ string: String) -> Data?
}

// The Base encoding used is home made, and has some differences. Especially,
// leading zeros are kept as single zeros when conversion happens.
extension Encoding {
    static func convertBytesToBase(_ bytes: Data) -> [UInt8] {
        var length = 0
        let size = sizeFromByte(size: bytes.count)
        var encodedBytes: [UInt8] = Array(repeating: 0, count: size)
        
        for b in bytes {
            var carry = Int(b)
            var i = 0
            for j in (0...encodedBytes.count - 1).reversed() where carry != 0 || i < length {
                carry += 256 * Int(encodedBytes[j])
                encodedBytes[j] = UInt8(carry % base)
                carry /= base
                i += 1
            }
            
            assert(carry == 0)
            
            length = i
        }
        
        var zerosToRemove = 0
        for b in encodedBytes {
            if b != 0 { break }
            zerosToRemove += 1
        }
        
        encodedBytes.removeFirst(zerosToRemove)
        return encodedBytes
    }
    
    static func encode(_ bytes: Data) -> String {
        var bytes = bytes
        var zerosCount = 0
        
        for b in bytes {
            if b != 0 { break }
            zerosCount += 1
        }
        
        bytes.removeFirst(zerosCount)
        
        let encodedBytes = convertBytesToBase(bytes)
        
        var str = ""
        while 0 < zerosCount {
            str += String(zeroAlphabet)
            zerosCount -= 1
        }
        
        for b in encodedBytes {
            str += String(baseAlphabets[baseAlphabets.index(baseAlphabets.startIndex, offsetBy: Int(b))])
        }
        
        return str
    }
    
    static func decode(_ string: String) -> Data? {
        guard !string.isEmpty else { return nil }
        
        var zerosCount = 0
        var length = 0
        for c in string {
            if c != zeroAlphabet { break }
            zerosCount += 1
        }
        let size = sizeFromBase(size: string.lengthOfBytes(using: .utf8) - zerosCount)
        var decodedBytes: [UInt8] = Array(repeating: 0, count: size)
        for c in string {
            guard let baseIndex = baseAlphabets.firstIndex(of: c) else { return nil }
            
            var carry = baseIndex.utf16Offset(in: baseAlphabets)
            var i = 0
            for j in (0...decodedBytes.count - 1).reversed() where carry != 0 || i < length {
                carry += base * Int(decodedBytes[j])
                decodedBytes[j] = UInt8(carry % 256)
                carry /= 256
                i += 1
            }
            
            assert(carry == 0)
            length = i
        }
        
        // skip leading zeros
        var zerosToRemove = 0
        
        for b in decodedBytes {
            if b != 0 { break }
            zerosToRemove += 1
        }
        decodedBytes.removeFirst(zerosToRemove)
        
        return Data(repeating: 0, count: zerosCount) + Data(decodedBytes)
    }
}
