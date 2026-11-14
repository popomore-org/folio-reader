import CryptoKit
import Foundation

let input = FileHandle.standardInput.readDataToEndOfFile()
if CommandLine.arguments.dropFirst().first == "generate" {
    print(Curve25519.Signing.PrivateKey().rawRepresentation.base64EncodedString())
} else if let encoded = String(data: input, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
          let raw = Data(base64Encoded: encoded) {
    print(try Curve25519.Signing.PrivateKey(rawRepresentation: raw).publicKey.rawRepresentation.base64EncodedString())
} else {
    FileHandle.standardError.write(Data("Expected a base64 Ed25519 seed on standard input.\n".utf8))
    exit(EXIT_FAILURE)
}
