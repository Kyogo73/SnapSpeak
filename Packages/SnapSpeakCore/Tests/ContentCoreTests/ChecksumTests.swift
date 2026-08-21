import Foundation
import ContentCore
import Testing

@Test func sha256KnownVectorAbc() {
    let digest = Checksum.sha256Hex(of: Data("abc".utf8))
    #expect(digest == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
}

@Test func verifyIsHexCaseInsensitive() {
    let data = Data("abc".utf8)
    #expect(Checksum.verify(data: data, expectedHex: "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD"))
    #expect(!Checksum.verify(data: data, expectedHex: "00"))
}
