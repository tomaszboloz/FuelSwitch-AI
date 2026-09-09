import Foundation
import CryptoKit

// Verify against the key embedded in the actual archived application, not
// merely the public half of whichever private key CI happens to have.
guard CommandLine.arguments.count == 4 else {
    fatalError("Usage: verify_update.swift archive signature extracted-app-Info.plist")
}
let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let plistData = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]))
let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as! [String: Any]
guard let encodedKey = plist["SUPublicEDKey"] as? String,
      let keyData = Data(base64Encoded: encodedKey),
      let signature = Data(base64Encoded: CommandLine.arguments[2]) else {
    fatalError("Missing or malformed Sparkle signature/public key")
}
let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
guard key.isValidSignature(signature, for: archive) else {
    fatalError("Archive signature does not match the application's Sparkle public key")
}
print("Sparkle EdDSA signature verified against bundled public key")
