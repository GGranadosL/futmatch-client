import CoreData
import Foundation
import SharedModels

// MARK: - AdminDependencyFactory

/// Wires together the repositories, use cases, and view models for the admin
/// panel. This is the only place allowed to instantiate concrete types for the
/// feature.
public struct AdminDependencyFactory {

    public init() {}

    // MARK: - Repositories

    func makeAdminDashboardRepository() -> AdminDashboardRepositoryProtocol {
        AdminDashboardRepository(fieldService: makeFieldService())
    }

    // MARK: - Use Cases

    func makeFetchAdminDashboardUseCase() -> FetchAdminDashboardUseCaseProtocol {
        FetchAdminDashboardUseCase(repository: makeAdminDashboardRepository())
    }

    // MARK: - View Models

    @MainActor
    func makeAdminHomeViewModel() -> AdminHomeViewModel {
        AdminHomeViewModel(fetchDashboardUseCase: makeFetchAdminDashboardUseCase())
    }

    // MARK: - Fields

    func makeFieldService() -> FieldServiceProtocol {
        FieldService()
    }

    func makeFieldRepository() -> FieldRepositoryProtocol {
        FieldRepository(service: makeFieldService())
    }

    func makeCreateFieldUseCase() -> CreateFieldUseCaseProtocol {
        CreateFieldUseCase(repository: makeFieldRepository())
    }

    @MainActor
    func makeNewFieldViewModel() -> NewFieldViewModel {
        NewFieldViewModel(createFieldUseCase: makeCreateFieldUseCase())
    }

    func makeUpdateFieldUseCase() -> UpdateFieldUseCaseProtocol {
        UpdateFieldUseCase(repository: makeFieldRepository())
    }

    @MainActor
    func makeEditFieldViewModel(field: AdminFieldItem) -> EditFieldViewModel {
        EditFieldViewModel(
            field: field,
            updateFieldUseCase: makeUpdateFieldUseCase()
        )
    }

    // MARK: - Field management (delete, link location, id-name catalog)

    public func makeDeleteFieldUseCase() -> DeleteFieldUseCaseProtocol {
        DeleteFieldUseCase(repository: makeFieldRepository())
    }

    public func makeLinkLocationUseCase() -> LinkLocationUseCaseProtocol {
        LinkLocationUseCase(repository: makeFieldRepository())
    }

    public func makeFetchFieldIdNamesUseCase() -> FetchFieldIdNamesUseCaseProtocol {
        FetchFieldIdNamesUseCase(repository: makeFieldRepository())
    }

    // MARK: - Field Images

    func makeUploadFieldImageUseCase() -> UploadFieldImageUseCaseProtocol {
        UploadFieldImageUseCase(repository: makeFieldRepository())
    }

    func makeReplaceFieldImageUseCase() -> ReplaceFieldImageUseCaseProtocol {
        ReplaceFieldImageUseCase(repository: makeFieldRepository())
    }

    func makeDeleteFieldImageUseCase() -> DeleteFieldImageUseCaseProtocol {
        DeleteFieldImageUseCase(repository: makeFieldRepository())
    }

    @MainActor
    func makeFieldImagesViewModel(field: AdminFieldItem, maxImages: Int) -> FieldImagesViewModel {
        FieldImagesViewModel(
            field: field,
            maxImages: maxImages,
            uploadUseCase: makeUploadFieldImageUseCase(),
            replaceUseCase: makeReplaceFieldImageUseCase(),
            deleteUseCase: makeDeleteFieldImageUseCase()
        )
    }

    // MARK: - Fields List

    func makeAdminFieldsRepository() -> AdminFieldsRepositoryProtocol {
        AdminFieldsRepository(service: makeFieldService())
    }

    func makeFetchAdminFieldsUseCase() -> FetchAdminFieldsUseCaseProtocol {
        FetchAdminFieldsUseCase(repository: makeAdminFieldsRepository())
    }

    @MainActor
    func makeAdminFieldsViewModel(context: NSManagedObjectContext? = nil) -> AdminFieldsViewModel {
        let cacheRepo = context.map { AdminFieldsCoreDataCacheRepository(context: $0) }
        return AdminFieldsViewModel(
            fetchFieldsUseCase: makeFetchAdminFieldsUseCase(),
            cacheRepo: cacheRepo
        )
    }

    // MARK: - Locations

    func makeLocationRepository(context: NSManagedObjectContext) -> LocationRepositoryProtocol {
        LocationRepository(context: context)
    }

    func makeFetchLocationsUseCase(context: NSManagedObjectContext) -> FetchLocationsUseCaseProtocol {
        FetchLocationsUseCase(repository: makeLocationRepository(context: context))
    }

    func makeGetLocationUseCase(context: NSManagedObjectContext) -> GetLocationUseCaseProtocol {
        GetLocationUseCase(repository: makeLocationRepository(context: context))
    }

    func makeCreateLocationUseCase(context: NSManagedObjectContext) -> CreateLocationUseCaseProtocol {
        CreateLocationUseCase(repository: makeLocationRepository(context: context))
    }

    func makeUpdateLocationUseCase(context: NSManagedObjectContext) -> UpdateLocationUseCaseProtocol {
        UpdateLocationUseCase(repository: makeLocationRepository(context: context))
    }

    func makeDeleteLocationUseCase(context: NSManagedObjectContext) -> DeleteLocationUseCaseProtocol {
        DeleteLocationUseCase(repository: makeLocationRepository(context: context))
    }

    func makeLocationCatalogRepository() -> LocationCatalogRepositoryProtocol {
        LocationCatalogRemoteConfigRepository()
    }

    func makeFetchLocationCatalogUseCase() -> FetchLocationCatalogUseCaseProtocol {
        FetchLocationCatalogUseCase(repository: makeLocationCatalogRepository())
    }

    @MainActor
    func makeNewLocationViewModel(context: NSManagedObjectContext) -> NewLocationViewModel {
        NewLocationViewModel(
            geocodingService: NominatimGeocodingService(),
            createLocationUseCase: makeCreateLocationUseCase(context: context),
            fetchCatalogUseCase: makeFetchLocationCatalogUseCase(),
            currentLocationProvider: CurrentLocationService()
        )
    }

    // MARK: - Matches

    func makeMatchAdminService() -> MatchAdminServiceProtocol {
        MatchAdminService()
    }

    func makeAdminMatchRepository() -> AdminMatchRepositoryProtocol {
        AdminMatchRepository(service: makeMatchAdminService())
    }

    func makeFetchAdminMatchesUseCase() -> FetchAdminMatchesUseCaseProtocol {
        FetchAdminMatchesUseCase(repository: makeAdminMatchRepository())
    }

    func makeCreateMatchUseCase() -> CreateMatchUseCaseProtocol {
        CreateMatchUseCase(repository: makeAdminMatchRepository())
    }

    @MainActor
    func makeAdminMatchesViewModel() -> AdminMatchesViewModel {
        AdminMatchesViewModel(fetchUseCase: makeFetchAdminMatchesUseCase())
    }

    @MainActor
    func makeNewMatchViewModel() -> NewMatchViewModel {
        NewMatchViewModel(
            createMatchUseCase: makeCreateMatchUseCase(),
            fetchFieldIdNamesUseCase: makeFetchFieldIdNamesUseCase()
        )
    }

    @MainActor
    func makeEditLocationViewModel(location: AdminLocation, context: NSManagedObjectContext) -> EditLocationViewModel {
        EditLocationViewModel(
            location: location,
            geocodingService: NominatimGeocodingService(),
            updateLocationUseCase: makeUpdateLocationUseCase(context: context),
            fetchCatalogUseCase: makeFetchLocationCatalogUseCase()
        )
    }
}
