import ContentCore
import Foundation
import SwiftData

extension PersistenceActor {
    public func upsertDownloadedCourse(_ dto: DownloadedCourseDTO) throws -> DownloadedCourseDTO {
        guard KnownContentSchemaVersions.contains(dto.schemaVersion) else {
            throw PersistenceError.unknownContentSchema(dto.schemaVersion)
        }
        let courseId = dto.courseId
        var descriptor = FetchDescriptor<DownloadedCourse>(
            predicate: #Predicate { $0.courseId == courseId }
        )
        descriptor.fetchLimit = 1
        let model: DownloadedCourse
        if let existing = try modelContext.fetch(descriptor).first {
            model = existing
        } else {
            model = DownloadedCourse(
                courseId: dto.courseId,
                sourceLanguage: dto.sourceLanguage,
                targetLanguage: dto.targetLanguage,
                revision: dto.revision,
                schemaVersion: dto.schemaVersion,
                releaseId: dto.releaseId,
                localPath: dto.localPath,
                downloadedAt: dto.downloadedAt,
                bytes: dto.bytes,
                checksumSha256: dto.checksumSha256
            )
            modelContext.insert(model)
        }
        model.sourceLanguage = dto.sourceLanguage
        model.targetLanguage = dto.targetLanguage
        model.revision = dto.revision
        model.schemaVersion = dto.schemaVersion
        model.releaseId = dto.releaseId
        model.localPath = dto.localPath
        model.downloadedAt = dto.downloadedAt
        model.bytes = dto.bytes
        model.checksumSha256 = dto.checksumSha256
        try modelContext.save()
        return PersistenceMapping.downloadedDTO(model)
    }

    public func downloadedCourses() throws -> [DownloadedCourseDTO] {
        try modelContext.fetch(FetchDescriptor<DownloadedCourse>()).map(PersistenceMapping.downloadedDTO)
    }

    public func deleteDownloadedCourse(courseId: String) throws {
        let target = courseId
        let descriptor = FetchDescriptor<DownloadedCourse>(
            predicate: #Predicate { $0.courseId == target }
        )
        for model in try modelContext.fetch(descriptor) {
            modelContext.delete(model)
        }
        try modelContext.save()
    }
}
