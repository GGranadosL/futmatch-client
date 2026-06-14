import Foundation

public protocol LinkLocationUseCaseProtocol {
    func execute(fieldId: String, locationId: String) async throws
}

public struct LinkLocationUseCase: LinkLocationUseCaseProtocol {
    private let repository: FieldRepositoryProtocol

    public init(repository: FieldRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(fieldId: String, locationId: String) async throws {
        try await repository.linkLocation(fieldId: fieldId, locationId: locationId)
    }
}
