import Foundation

public protocol FetchFieldAttributeCatalogsUseCaseProtocol {
    func execute() async -> FieldAttributeCatalogs
}

public struct FetchFieldAttributeCatalogsUseCase: FetchFieldAttributeCatalogsUseCaseProtocol {
    private let repository: FieldAttributeCatalogRepositoryProtocol

    public init(repository: FieldAttributeCatalogRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async -> FieldAttributeCatalogs {
        await repository.fetchCatalogs()
    }
}
