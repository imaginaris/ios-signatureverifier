import Quick
import Nimble
@testable import RSignatureVerifier

class RealSignatureVerifierSpec: QuickSpec {
    override func spec() {

        context("RealSignatureVerifier") {

            let bundleMock = BundleMock()
            let keyStore = KeyStore(service: "unit-tests")

            var fetcher: FetcherMock!
            var verifier: VerifierMock!
            var svModule: RealSignatureVerifier!

            // Fetcher won't work if endpoint or appid are invalid
            // so need to set something valid
            bundleMock.mockEndpoint = "https://www.endpoint.com"
            bundleMock.mockAppId = "foo-id"

            beforeEach {
                keyStore.empty()
                verifier = VerifierMock()
                fetcher = FetcherMock()
                svModule = RealSignatureVerifier(fetcher: fetcher, keyStore: keyStore, verifier: verifier)
            }

            afterEach {
                UserDefaults.standard.removePersistentDomain(forName: "RealSignatureVerifierSpec")
            }

            context("when calling verify method") {
                let mockData = "data".data(using: .utf8)!

                context("and key exists in the cache") {
                    let keyId = "cachedKeyId"

                    beforeEach {
                        keyStore.addKey(key: "cached-key", for: keyId)
                    }

                    it("will not call fetcher") {
                        waitUntil { done in
                            svModule.verify(signature: "siganture", keyId: keyId, data: mockData) { _ in
                                done()
                            }
                        }
                        expect(fetcher.fetchKeyCalledNumTimes).to(equal(0))
                    }

                    it("will call Verifier using cached key") {
                        waitUntil { done in
                            svModule.verify(signature: "siganture", keyId: keyId, data: mockData) { _ in
                                done()
                            }
                        }
                        expect(verifier.lastUsedKey).to(equal("cached-key"))
                    }

                    it("will pass verification result to resultHandler (negative)") {
                        verifier.verifyOK = false
                        waitUntil { done in
                            svModule.verify(signature: "siganture", keyId: keyId, data: mockData) { verified in
                                expect(verified).to(beFalse())
                                done()
                            }
                        }
                    }

                    it("will pass verification result to resultHandler (positive)") {
                        verifier.verifyOK = true
                        waitUntil { done in
                            svModule.verify(signature: "siganture", keyId: keyId, data: mockData) { verified in
                                expect(verified).to(beTrue())
                                done()
                            }
                        }
                    }
                }

                context("and key does not exist in the cache") {
                    let keyId = "fetchedKeyId"

                    beforeEach {
                        fetcher.fetchedKey = KeyModel(identifier: keyId, key: "fetched-key")
                    }

                    it("will call fetcher to fetch the key") {
                        waitUntil { done in
                            svModule.verify(signature: "siganture", keyId: keyId, data: mockData) { _ in
                                done()
                            }
                        }
                        expect(fetcher.fetchKeyCalledNumTimes).to(equal(1))
                    }

                    it("will pass negative result to resultHandler if fetched key was nil") {
                        fetcher.fetchedKey = nil
                        waitUntil { done in
                            svModule.verify(signature: "siganture", keyId: keyId, data: mockData) { verified in
                                expect(verified).to(beFalse())
                                done()
                            }
                        }
                    }

                    it("will pass verification result to resultHandler (negative)") {
                        verifier.verifyOK = false
                        waitUntil { done in
                            svModule.verify(signature: "siganture", keyId: keyId, data: mockData) { verified in
                                expect(verified).to(beFalse())
                                done()
                            }
                        }
                    }

                    it("will pass verification result to resultHandler (positive)") {
                        verifier.verifyOK = true
                        waitUntil { done in
                            svModule.verify(signature: "siganture", keyId: keyId, data: mockData) { verified in
                                expect(verified).to(beTrue())
                                done()
                            }
                        }
                    }

                    it("will add fetched key to the KeyStore") {
                        verifier.verifyOK = true
                        waitUntil { done in
                            svModule.verify(signature: "siganture", keyId: keyId, data: mockData) { _ in
                                done()
                            }
                        }
                        expect(keyStore.key(for: keyId)).to(equal("fetched-key"))
                    }

                    it("will add fetched key to the KeyStore even if verification was unsuccessful") {
                        verifier.verifyOK = false
                        waitUntil { done in
                            svModule.verify(signature: "siganture", keyId: keyId, data: mockData) { _ in
                                done()
                            }
                        }
                        expect(keyStore.key(for: keyId)).to(equal("fetched-key"))
                    }

                    it("will not add fetched key to the KeyStore if the key is empty") {
                        verifier.verifyOK = true
                        fetcher.fetchedKey = nil
                        waitUntil { done in
                            svModule.verify(signature: "siganture", keyId: keyId, data: mockData) { _ in
                                done()
                            }
                        }
                        expect(keyStore.key(for: keyId)).to(beNil())
                    }
                }
            }
        }
    }
}