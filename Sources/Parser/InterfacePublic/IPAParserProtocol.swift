import Foundation
import IPAFoundation

public protocol IPAParserProtocol {
    func parse(ipaURL: URL) throws -> IPAContent
    func cleanup()
}