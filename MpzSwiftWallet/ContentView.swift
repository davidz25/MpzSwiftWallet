//
//  ContentView.swift
//  MpzSwiftWallet
//
//  Created by David Zeuthen on 6/7/25.
//

import SwiftUI
import Multipaz

struct WalletData {
    let storage: Storage
    let secureArea: SecureArea
    let secureAreaRepository: SecureAreaRepository
    let documentTypeRepository: DocumentTypeRepository
    let documentStore: DocumentStore
    let readerTrustManager: TrustManager

    let presentmentModel = PresentmentModel()
    @State var presentmentState = PresentmentModel.State.idle
    
    init() async {
        storage = try! await Platform.shared.getNonBackedUpStorage()
        secureArea = try! await Platform.shared.getSecureArea(storage: storage)
        secureAreaRepository = SecureAreaRepository.Builder()
            .add(secureArea: secureArea)
            .build()
        documentTypeRepository = DocumentTypeRepository()
        documentTypeRepository.addDocumentType(documentType: DrivingLicense.shared.getDocumentType())
        documentStore = DocumentStore.Builder(
            storage: storage,
            secureAreaRepository: secureAreaRepository
        ).build()
        if (try! await documentStore.listDocuments().isEmpty) {
            let now = ClockSystem.shared.now()
            let signedAt = now
            let validFrom = now
            //let validUntil = now.plus(value: 365, unit: DateTimeUnit.TimeBased(nanoseconds: 86400*1000*1000*1000))
            let validUntil = now.plus(duration: 365*86400*1000*1000*1000)
            print("validFrom: \(validFrom)")
            print("validUntil: \(validUntil)")
            let iacaKey = Crypto.shared.createEcPrivateKey(curve: EcCurve.p256)
            let iacaCert = MdocUtil.shared.generateIacaCertificate(
                iacaKey: iacaKey,
                subject: X500Name.companion.fromName(name: "CN=Test IACA Key"),
                serial: ASN1Integer.companion.fromRandom(numBits: 128, random: KotlinRandom.companion),
                validFrom: validFrom,
                validUntil: validUntil,
                issuerAltNameUrl: "https://issuer.example.com",
                crlUrl: "https://issuer.example.com/crl"
            )
            let dsKey = Crypto.shared.createEcPrivateKey(curve: EcCurve.p256)
            let dsCert = MdocUtil.shared.generateDsCertificate(
                iacaCert: iacaCert,
                iacaKey: iacaKey,
                dsKey: dsKey.publicKey,
                subject: X500Name.companion.fromName(name: "CN=Test DS Key"),
                serial:  ASN1Integer.companion.fromRandom(numBits: 128, random: KotlinRandom.companion),
                validFrom: validFrom,
                validUntil: validUntil
            )
            let document = try! await documentStore.createDocument(
                displayName: "Erika's Driving License",
                typeDisplayName: "Utopia Driving License",
                cardArt: nil,
                issuerLogo: nil,
                other: nil
            )
            let _ = try! await DrivingLicense.shared.getDocumentType().createMdocCredentialWithSampleData(
                document: document,
                secureArea: secureArea,
                createKeySettings: CreateKeySettings(
                    algorithm: Algorithm.esp256,
                    nonce: ByteStringBuilder(initialCapacity: 3).appendString(string: "123").toByteString(),
                    userAuthenticationRequired: true
                ),
                dsKey: dsKey,
                dsCertChain: X509CertChain(certificates: [dsCert]),
                signedAt: signedAt,
                validFrom: validFrom,
                validUntil: validUntil,
                expectedUpdate: nil,
                domain: "mdoc")
        }
        let owfMultipazReaderRootCert = X509Cert.companion.fromPem(
            pemEncoding: """
                -----BEGIN CERTIFICATE-----
                MIICUTCCAdegAwIBAgIQppKZHI1iPN290JKEA79OpzAKBggqhkjOPQQDAzArMSkwJwYDVQQDDCBP
                V0YgTXVsdGlwYXogVGVzdEFwcCBSZWFkZXIgUm9vdDAeFw0yNDEyMDEwMDAwMDBaFw0zNDEyMDEw
                MDAwMDBaMCsxKTAnBgNVBAMMIE9XRiBNdWx0aXBheiBUZXN0QXBwIFJlYWRlciBSb290MHYwEAYH
                KoZIzj0CAQYFK4EEACIDYgAE+QDye70m2O0llPXMjVjxVZz3m5k6agT+wih+L79b7jyqUl99sbeU
                npxaLD+cmB3HK3twkA7fmVJSobBc+9CDhkh3mx6n+YoH5RulaSWThWBfMyRjsfVODkosHLCDnbPV
                o4G/MIG8MA4GA1UdDwEB/wQEAwIBBjASBgNVHRMBAf8ECDAGAQH/AgEAMFYGA1UdHwRPME0wS6BJ
                oEeGRWh0dHBzOi8vZ2l0aHViLmNvbS9vcGVud2FsbGV0LWZvdW5kYXRpb24tbGFicy9pZGVudGl0
                eS1jcmVkZW50aWFsL2NybDAdBgNVHQ4EFgQUq2Ub4FbCkFPx3X9s5Ie+aN5gyfUwHwYDVR0jBBgw
                FoAUq2Ub4FbCkFPx3X9s5Ie+aN5gyfUwCgYIKoZIzj0EAwMDaAAwZQIxANN9WUvI1xtZQmAKS4/D
                ZVwofqLNRZL/co94Owi1XH5LgyiBpS3E8xSxE9SDNlVVhgIwKtXNBEBHNA7FKeAxKAzu4+MUf4gz
                8jvyFaE0EUVlS2F5tARYQkU6udFePucVdloi
                -----END CERTIFICATE-----
                """.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        readerTrustManager = TrustManager()
        readerTrustManager.addTrustPoint(trustPoint: TrustPoint(
            certificate: owfMultipazReaderRootCert,
            displayName: "OWF Multipaz TestApp",
            displayIcon: nil
        ))
    }
}


var walletData: WalletData? = nil

struct ContentView: View {
    @State private var presentmentState: PresentmentModel.State = .idle
    @State private var qrCode: UIImage? = nil
    
    init() {
        initWalletData()
    }
    
    func initWalletData() {
        Task {
            //walletData = await WalletData()
            //await walletData!.listenForStateChange()
            //walletData?.presentmentModel.state.
        }
    }
    
    var body: some View {
        VStack {
            switch presentmentState {
            case .idle:
                handleIdle()
                
            case .connecting:
                handleConnecting()

            case .waitingForSource:
                handleWaitingForSource()

            case .processing:
                handleProcessing()
                
            case .waitingForDocumentSelection:
                handleWaitingForDocumentSelection()
                
            case .waitingForConsent:
                handleWaitingForConsent()
                
            case .completed:
                handleCompleted()
            }
        }
        .padding()
        .onAppear {
            Task {
                walletData = await WalletData()
                for await state in walletData!.presentmentModel.state {
                    presentmentState = state
                }
            }
        }
    }

    private func handleIdle() -> some View {
        return Button(action: {
            Task {
                walletData!.presentmentModel.reset()
                walletData!.presentmentModel.setConnecting()
                let connectionMethods = [
                    MdocConnectionMethodBle(
                        supportsPeripheralServerMode: false,
                        supportsCentralClientMode: true,
                        peripheralServerModeUuid: nil,
                        centralClientModeUuid: UUID.companion.randomUUID(),
                        peripheralServerModePsm: nil,
                        peripheralServerModeMacAddress: nil)
                ]
                let eDeviceKey = Crypto.shared.createEcPrivateKey(curve: EcCurve.p256)
                let advertisedTransports = try! await ConnectionHelperKt.advertise(
                    connectionMethods,
                    role: MdocRole.mdoc,
                    transportFactory: MdocTransportFactoryDefault.shared,
                    options: MdocTransportOptions(bleUseL2CAP: true)
                )
                let engagementGenerator = EngagementGenerator(
                    eSenderKey: eDeviceKey.publicKey,
                    version: "1.0"
                )
                engagementGenerator.addConnectionMethods(
                    connectionMethods: advertisedTransports.map({transport in transport.connectionMethod})
                )
                let encodedDeviceEngagement = ByteString(bytes: engagementGenerator.generate())
                let qrCodeUrl = "mdoc:" + encodedDeviceEngagement
                    .toByteArray(startIndex: 0, endIndex: encodedDeviceEngagement.size)
                    .toBase64Url()
                qrCode = generateQrCode(url: qrCodeUrl)!
                let transport = try! await ConnectionHelperKt.waitForConnection(
                    advertisedTransports,
                    eSenderKey: eDeviceKey.publicKey,
                    coroutineScope: walletData!.presentmentModel.presentmentScope
                )
                walletData!.presentmentModel.setMechanism(
                    mechanism: MdocPresentmentMechanism(
                        transport: transport,
                        eDeviceKey: eDeviceKey,
                        encodedDeviceEngagement: encodedDeviceEngagement,
                        handover: Simple.companion.NULL,
                        engagementDuration: nil,
                        allowMultipleRequests: false
                    )
                )
                qrCode = nil
            }
        }) {
            Text("Present mDL via QR")
        }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
    }

    private func handleConnecting() -> some View {
        return VStack {
            Text("Present QR code to reader")
            if (qrCode != nil) {
                Image(uiImage: qrCode!).padding(.all, 20)
            }
            Button(action: {
                walletData!.presentmentModel.reset()
            }) {
                Text("Cancel")
            }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        }
    }

    private func handleWaitingForSource() -> some View {
        walletData!.presentmentModel.setSource(source: SimplePresentmentSource(
            documentStore: walletData!.documentStore,
            documentTypeRepository: walletData!.documentTypeRepository,
            readerTrustManager: walletData!.readerTrustManager,
            preferSignatureToKeyAgreement: true,
            domainMdocSignature: "mdoc",
            domainMdocKeyAgreement: nil,
            domainKeylessSdJwt: nil,
            domainKeyBoundSdJwt: nil
        ))
        return EmptyView()
    }
    
    private func handleProcessing() -> some View {
        return Text("Communicating with reader")
    }

    private func handleWaitingForDocumentSelection() -> some View {
        // In this sample we just pick the first document, more sophisticated
        // wallets present a document picker for the user
        //
        walletData!.presentmentModel.documentSelected(
            document: walletData!.presentmentModel.availableDocuments.first
        )
        return EmptyView()
    }

    private func handleWaitingForConsent() -> some View {
        return VStack {
            let consentData = walletData!.presentmentModel.consentData
            if (consentData.trustPoint == nil) {
                Text("Unknown mdoc reader is requesting information")
                    .font(.title)
            } else {
                Text("Trusted mdoc reader **\(consentData.trustPoint!.displayName!)** is requesting information")
                    .font(.title)
            }
            VStack {
                ForEach(consentData.request.requestedClaims, id: \.self) { requestedClaim in
                    Text(requestedClaim.displayName)
                        .font(.body)
                        .fontWeight(.thin)
                        .textScale(.secondary)

                }
            }
            HStack {
                Button(action: {
                    walletData!.presentmentModel.reset()
                }) {
                    Text("Cancel")
                }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)

                Button(action: {
                    walletData!.presentmentModel.consentReviewed(consentObtained: true)
                }) {
                    Text("Consent")
                }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
            }
        }
    }
    
    private func handleCompleted() -> some View {
        Task {
            try! await delay(timeMillis: 2500)
            walletData!.presentmentModel.reset()
        }
        if (walletData!.presentmentModel.error == nil) {
            return VStack {
                Image(systemName: "checkmark.circle")
                    .renderingMode(.original)
                    .symbolRenderingMode(SymbolRenderingMode.multicolor)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .symbolEffect(.bounce)
                Text("The information was shared")
            }
        } else {
            return VStack {
                Image(systemName: "xmark")
                    .renderingMode(.original)
                    .symbolRenderingMode(SymbolRenderingMode.multicolor)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .symbolEffect(.bounce)
                Text("Something went wrong")
            }
        }
    }
    
    private func generateQrCode(url: String) -> UIImage? {
        let data = url.data(using: String.Encoding.ascii)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 4, y: 4)
            if let output = filter.outputImage?.transformed(by: transform) {
                let context = CIContext()
                let cgImage = context.createCGImage(output, from: CGRect(x: 0, y: 0, width: output.extent.width, height: output.extent.height))
                return UIImage(cgImage: cgImage!)
            }
        }
        return nil
    }
}

#Preview {
    ContentView()
}
