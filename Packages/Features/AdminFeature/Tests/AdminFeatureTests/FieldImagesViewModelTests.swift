import XCTest
import UIKit
@testable import AdminFeature

@MainActor
final class FieldImagesViewModelTests: XCTestCase {

    // MARK: - Init

    func test_init_buildsSlots_andPrefillsExistingImages() {
        let field = makeField(images: [
            FieldImage(id: "img0", url: "https://cdn/0.jpg", position: 0)
        ])
        let sut = makeSUT(field: field, maxImages: 2)

        XCTAssertEqual(sut.slots.count, 2)

        XCTAssertEqual(sut.slots[0].position, 0)
        XCTAssertEqual(sut.slots[0].imageId, "img0")
        XCTAssertEqual(sut.slots[0].remoteURL, "https://cdn/0.jpg")
        XCTAssertTrue(sut.slots[0].hasImage)

        XCTAssertEqual(sut.slots[1].position, 1)
        XCTAssertNil(sut.slots[1].imageId)
        XCTAssertFalse(sut.slots[1].hasImage)
    }

    func test_init_clampsToAtLeastOneSlot() {
        let sut = makeSUT(field: makeField(), maxImages: 0)
        XCTAssertEqual(sut.slots.count, 1)
    }

    // MARK: - Upload (empty slot)

    func test_handlePicked_onEmptySlot_uploads_andStoresReturnedId() async {
        let upload = MockUploadFieldImageUseCase()
        upload.stubbedId = "uploaded-id"
        let replace = MockReplaceFieldImageUseCase()
        let sut = makeSUT(field: makeField(), maxImages: 1, upload: upload, replace: replace)

        await sut.handlePicked(makeImage(), at: 0)

        XCTAssertEqual(upload.callCount, 1)
        XCTAssertEqual(upload.lastPosition, 0)
        XCTAssertEqual(replace.callCount, 0)
        XCTAssertEqual(sut.slots[0].imageId, "uploaded-id")
        XCTAssertNotNil(sut.slots[0].localImage)
        XCTAssertNil(sut.slots[0].remoteURL)
        XCTAssertFalse(sut.slots[0].isBusy)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Replace (existing slot)

    func test_handlePicked_onExistingSlot_replaces_notUploads() async {
        let upload = MockUploadFieldImageUseCase()
        let replace = MockReplaceFieldImageUseCase()
        replace.stubbedId = "replaced-id"
        let field = makeField(images: [FieldImage(id: "old-id", url: "https://cdn/0.jpg", position: 0)])
        let sut = makeSUT(field: field, maxImages: 1, upload: upload, replace: replace)

        await sut.handlePicked(makeImage(), at: 0)

        XCTAssertEqual(replace.callCount, 1)
        XCTAssertEqual(replace.lastImageId, "old-id")
        XCTAssertEqual(upload.callCount, 0)
        XCTAssertEqual(sut.slots[0].imageId, "replaced-id")
        XCTAssertNil(sut.slots[0].remoteURL)
    }

    // MARK: - Failure path

    func test_handlePicked_whenUseCaseThrows_revertsPreview_andSetsError() async {
        let upload = MockUploadFieldImageUseCase()
        upload.error = SampleError.boom
        let sut = makeSUT(field: makeField(), maxImages: 1, upload: upload)

        await sut.handlePicked(makeImage(), at: 0)

        XCTAssertNil(sut.slots[0].localImage)   // optimistic preview reverted
        XCTAssertNil(sut.slots[0].imageId)
        XCTAssertFalse(sut.slots[0].isBusy)
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - Delete

    func test_removeImage_onExistingSlot_deletes_andClearsSlot() async {
        let delete = MockDeleteFieldImageUseCase()
        let field = makeField(images: [FieldImage(id: "img0", url: "https://cdn/0.jpg", position: 0)])
        let sut = makeSUT(field: field, maxImages: 1, delete: delete)

        await sut.removeImage(at: 0)

        XCTAssertEqual(delete.callCount, 1)
        XCTAssertEqual(delete.lastImageId, "img0")
        XCTAssertNil(sut.slots[0].imageId)
        XCTAssertNil(sut.slots[0].remoteURL)
        XCTAssertNil(sut.slots[0].localImage)
        XCTAssertFalse(sut.slots[0].hasImage)
    }

    func test_removeImage_onEmptySlot_doesNotCallDelete() async {
        let delete = MockDeleteFieldImageUseCase()
        let sut = makeSUT(field: makeField(), maxImages: 1, delete: delete)

        await sut.removeImage(at: 0)

        XCTAssertEqual(delete.callCount, 0)
        XCTAssertNil(sut.errorMessage)
    }

    func test_removeImage_whenDeleteThrows_keepsImage_andSetsError() async {
        let delete = MockDeleteFieldImageUseCase()
        delete.error = SampleError.boom
        let field = makeField(images: [FieldImage(id: "img0", url: "https://cdn/0.jpg", position: 0)])
        let sut = makeSUT(field: field, maxImages: 1, delete: delete)

        await sut.removeImage(at: 0)

        XCTAssertEqual(sut.slots[0].imageId, "img0")   // unchanged
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.slots[0].isBusy)
    }

    // MARK: - Helpers

    private func makeSUT(
        field: AdminFieldItem,
        maxImages: Int,
        upload: UploadFieldImageUseCaseProtocol = MockUploadFieldImageUseCase(),
        replace: ReplaceFieldImageUseCaseProtocol = MockReplaceFieldImageUseCase(),
        delete: DeleteFieldImageUseCaseProtocol = MockDeleteFieldImageUseCase()
    ) -> FieldImagesViewModel {
        FieldImagesViewModel(
            field: field,
            maxImages: maxImages,
            uploadUseCase: upload,
            replaceUseCase: replace,
            deleteUseCase: delete
        )
    }

    private func makeField(images: [FieldImage] = []) -> AdminFieldItem {
        AdminFieldItem(
            id: "field-1",
            name: "Cancha Central",
            priceInCents: 50_000,
            capacity: 10,
            images: images
        )
    }

    private func makeImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }
}

// MARK: - Mocks

private enum SampleError: Error { case boom }

private final class MockUploadFieldImageUseCase: UploadFieldImageUseCaseProtocol {
    var stubbedId = "upload-id"
    var error: Error?
    private(set) var callCount = 0
    private(set) var lastPosition: Int?

    func execute(fieldId: String, position: Int, imageData: Data) async throws -> String {
        callCount += 1
        lastPosition = position
        if let error { throw error }
        return stubbedId
    }
}

private final class MockReplaceFieldImageUseCase: ReplaceFieldImageUseCaseProtocol {
    var stubbedId = "replace-id"
    var error: Error?
    private(set) var callCount = 0
    private(set) var lastImageId: String?

    func execute(fieldId: String, imageId: String, imageData: Data) async throws -> String {
        callCount += 1
        lastImageId = imageId
        if let error { throw error }
        return stubbedId
    }
}

private final class MockDeleteFieldImageUseCase: DeleteFieldImageUseCaseProtocol {
    var error: Error?
    private(set) var callCount = 0
    private(set) var lastImageId: String?

    func execute(fieldId: String, imageId: String) async throws {
        callCount += 1
        lastImageId = imageId
        if let error { throw error }
    }
}
